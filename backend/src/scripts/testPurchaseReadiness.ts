import assert from 'node:assert/strict';
import { Request, Response, NextFunction } from 'express';
import { Pool } from 'pg';
import { AppError } from '../core/errors/AppError';
import { errorHandler } from '../core/middleware/errorHandler';
import { supabaseProfileService } from '../modules/auth/services/supabaseProfileService';
import { createPurchaseRoutes } from '../modules/purchases/purchaseRoutes';
import { PurchaseVerificationService, PurchaseVerifier } from '../modules/purchases/purchaseVerificationService';
import { PostgresStorePurchaseRepository, purchaseIdentities, StorePurchaseRepository, VerifiedEntitlementProjector } from '../modules/purchases/storePurchaseRepository';
import { StoreTransaction, VerifiedStorePurchase } from '../modules/purchases/purchaseTypes';

const fails = (code: string) => (e: unknown) => e instanceof AppError && e.code === code;
const purchase: VerifiedStorePurchase = {
  provider: 'apple', productId: 'monthly', externalTransactionId: 'txn', originalTransactionId: 'original',
  status: 'active', purchasedAt: new Date('2026-10-16'), expiresAt: new Date('2026-11-16'), environment: 'sandbox',
};
const evidence = { provider: 'apple' as const, productId: 'monthly', purchaseEvidence: 'SECRET_PURCHASE_EVIDENCE' };
let passed = 0;
async function test(name: string, fn: () => Promise<void>) { await fn(); passed++; console.log(`PASS ${name}`); }

// Exercise the real repository SQL/control flow with a transactional test double.
// Live PostgreSQL constraint tests also live in supabase/tests/premium_store.sql.
function fixture() {
  let owners = new Map<string, string>();
  let records = new Map<string, StoreTransaction>();
  let projections = new Map<string, string>();
  let before: [typeof owners, typeof records, typeof projections];
  let writesFail = false;
  const query = async (sql: string, args: unknown[] = []) => {
    let rows: unknown[] = [];
    if (sql === 'begin') before = [new Map(owners), new Map(records), new Map(projections)];
    else if (sql === 'rollback') [owners, records, projections] = before;
    else if (sql.includes('insert into public.store_purchase_identities')) {
      const key = args.slice(0, 3).join(':');
      if (!owners.has(key)) owners.set(key, String(args[3]));
    } else if (sql.includes('select user_id from public.store_purchase_identities')) {
      const owner = owners.get(args.slice(0, 3).join(':'));
      if (owner) rows = [{ user_id: owner }];
    } else if (sql.includes('insert into public.store_purchase_transactions')) {
      if (writesFail) throw Error('database error containing SECRET_PURCHASE_EVIDENCE');
      assert.ok(sql.includes('on conflict(provider,external_transaction_id) do update'));
      assert.ok(sql.includes('store_purchase_transactions.user_id=excluded.user_id'));
      const key = `${args[1]}:${args[3]}`;
      const existing = records.get(key);
      const record = { ...purchase, id: existing?.id ?? `row-${records.size}`, userId: String(args[0]),
        provider: args[1], externalTransactionId: args[3] } as StoreTransaction;
      records.set(key, record); rows = [{ id: record.id }];
    } else if (sql === 'test-project') projections.set(String(args[0]), String(args[1]));
    else assert.ok(sql === 'commit' || sql.includes('pg_advisory_xact_lock'), sql);
    return { rows, rowCount: rows.length };
  };
  const client = { query, release() {} };
  const pool = { query, connect: async () => client } as unknown as Pool;
  const repository = new PostgresStorePurchaseRepository(() => pool);
  const projector: VerifiedEntitlementProjector = {
    projectVerifiedEntitlement: async (tx, query) => { await query('test-project', [tx.userId, tx.id]); },
  };
  const verifier: PurchaseVerifier = { verify: async () => purchase };
  const service = new PurchaseVerificationService(repository, projector, { apple: verifier, google: verifier });
  return { repository, projector, service, failWrites: () => { writesFail = true; },
    state: () => ({ owners, records, projections }) };
}
async function run() {
  await test('unconfigured providers fail before persistence', async () => {
    const repository: StorePurchaseRepository = {
      findByIdentity: async () => null,
      persistAndProject: async () => { assert.fail('must not persist'); },
    };
    const service = new PurchaseVerificationService(repository, { projectVerifiedEntitlement: async () => assert.fail('must not project') });
    for (const provider of ['apple', 'google'] as const) await assert.rejects(service.verifyAndSync('owner', { ...evidence, provider }), fails('STORE_PURCHASE_VERIFICATION_NOT_CONFIGURED'));
  });
  await test('replay is idempotent, account ownership and renewal chain protected', async () => {
    const f = fixture();
    const first = await f.service.verifyAndSync('owner', evidence);
    const second = await f.service.verifyAndSync('owner', evidence);
    assert.equal(first.transactionId, second.transactionId);
    assert.equal(f.state().records.size, 1); assert.equal(f.state().projections.size, 1);
    assert.equal((await f.repository.findByIdentity(purchaseIdentities(purchase)[0]))?.userId, 'owner');
    await assert.rejects(f.service.verifyAndSync('attacker', evidence), fails('STORE_PURCHASE_ACCOUNT_CONFLICT'));
    await assert.rejects(f.repository.persistAndProject('attacker', { ...purchase, externalTransactionId: 'renewal' }, f.projector), fails('STORE_PURCHASE_ACCOUNT_CONFLICT'));
    assert.equal(f.state().records.size, 1); assert.equal(f.state().projections.has('attacker'), false);
  });
  await test('Google token hash globally owns multiple renewal IDs', async () => {
    const f = fixture();
    const google = { ...purchase, provider: 'google' as const, originalTransactionId: undefined, purchaseTokenHash: 'a'.repeat(64) };
    await f.repository.persistAndProject('owner', google, f.projector);
    await f.repository.persistAndProject('owner', { ...google, externalTransactionId: 'renewal' }, f.projector);
    assert.equal(f.state().records.size, 2);
    await assert.rejects(f.repository.persistAndProject('attacker', { ...google, externalTransactionId: 'different' }, f.projector), fails('STORE_PURCHASE_ACCOUNT_CONFLICT'));
    assert.equal(f.state().records.size, 2);
  });
  await test('verifier failure never projects or leaks provider errors', async () => {
    const f = fixture();
    const bad = { verify: async () => { throw Error(evidence.purchaseEvidence); } };
    const service = new PurchaseVerificationService(f.repository, f.projector, { apple: bad, google: bad });
    await assert.rejects(service.verifyAndSync('owner', evidence), fails('STORE_PURCHASE_VERIFICATION_FAILED'));
    assert.equal(f.state().records.size, 0); assert.equal(f.state().projections.size, 0);
  });
  await test('persistence and projection outages roll back all writes', async () => {
    const f = fixture(); f.failWrites();
    await assert.rejects(f.service.verifyAndSync('owner', evidence), fails('STORE_PURCHASE_PERSISTENCE_FAILED'));
    assert.equal(f.state().projections.size, 0); assert.equal(f.state().owners.size, 0);
    const g = fixture();
    await assert.rejects(g.repository.persistAndProject('owner', purchase, {
      projectVerifiedEntitlement: async () => { throw Error('projection outage'); },
    }));
    assert.equal(g.state().records.size, 0); assert.equal(g.state().owners.size, 0);
  });
  await test('malformed verified identities fail before database writes', async () => {
    const f = fixture();
    await assert.rejects(f.repository.persistAndProject('owner', { ...purchase, originalTransactionId: undefined }, f.projector), fails('INVALID_VERIFIED_STORE_PURCHASE'));
    assert.equal(f.state().owners.size, 0);
  });
  await test('HTTP auth, strict request contract, binding, restore and safe logs', async () => {
    const oldVerify = supabaseProfileService.verifyAccessToken;
    const oldProfile = supabaseProfileService.ensureProfile;
    const captured: string[] = [];
    const oldError = console.error;
    console.error = (...args: unknown[]) => { captured.push(args.join(' ')); };
    supabaseProfileService.verifyAccessToken = async () => ({ id: 'owner' }) as never;
    supabaseProfileService.ensureProfile = async () => ({ id: 'owner' }) as never;
    const f = fixture();
    const configured = createPurchaseRoutes(f.service);
    const unconfigured = createPurchaseRoutes();
    const post = async (path: string, body: object, auth = true) => {
      let status = 200;
      let payload: unknown;
      const req = { method: 'POST', url: path.replace('/api/purchases', '').replace('/unconfigured', ''),
        headers: auth ? { authorization: 'Bearer test' } : {}, body } as Request;
      let done: () => void = () => {};
      const complete = new Promise<void>(resolve => { done = resolve; });
      const res = {
        status(code: number) { status = code; return this; },
        json(value: unknown) { payload = value; done(); return this; },
      } as unknown as Response;
      const next: NextFunction = (error?: unknown) => {
        if (error) errorHandler(error as Error, req, res, () => {});
        else { assert.fail('route was not handled'); }
      };
      const router = path.startsWith('/unconfigured') ? unconfigured : configured;
      (router as unknown as { handle: (req: Request, res: Response, next: NextFunction) => void }).handle(req, res, next);
      await complete;
      return { status, json: async () => payload, text: async () => JSON.stringify(payload) };
    };
    try {
      for (const path of ['/verify', '/restore/sync']) {
        assert.equal((await post('/api/purchases' + path, evidence, false)).status, 401);
        for (const extra of [{ isPremium: true }, { tier: 'premium' }, { status: 'active' }, { expiresAt: '2099' }, { userId: 'victim' }]) {
          assert.equal((await post('/api/purchases' + path, { ...evidence, ...extra })).status, 400);
        }
        const missing = await post('/unconfigured' + path, evidence);
        assert.equal(missing.status, 503);
        assert.equal((await missing.json() as { code: string }).code, 'STORE_PURCHASE_VERIFICATION_NOT_CONFIGURED');
        assert.equal((await post('/api/purchases' + path, evidence)).status, 200);
      }
      assert.equal([...f.state().records.values()][0].userId, 'owner');
      f.failWrites();
      const failed = await post('/api/purchases/verify', evidence);
      assert.equal(failed.status, 503);
      assert.ok(!(await failed.text()).includes(evidence.purchaseEvidence));
      assert.ok(!captured.join(' ').includes(evidence.purchaseEvidence));
    } finally {
      supabaseProfileService.verifyAccessToken = oldVerify; supabaseProfileService.ensureProfile = oldProfile;
      console.error = oldError;
    }
  });
  console.log(`PASS ${passed} purchase-readiness test groups`);
}
run().catch(error => { console.error(error); process.exitCode = 1; });
