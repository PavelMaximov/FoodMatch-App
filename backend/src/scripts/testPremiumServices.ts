import assert from 'node:assert/strict';
import { AppError } from '../core/errors/AppError';
import { CoupleSessionRecord } from '../domain/repositories/types';
import { queryPostgres } from '../shared/db/postgresClient';
import { EntitlementService } from '../modules/entitlements/services/entitlementService';
import { requireAdvancedFilterAccess } from '../modules/entitlements/services/featureAccessService';
import { SharedShoppingListService } from '../modules/shopping-list/services/sharedShoppingListService';
import { MatchService } from '../modules/matches/services/matchService';

let passed = 0;
async function test(name: string, task: () => Promise<void>) {
  await task(); passed++; console.log(`PASS ${name}`);
}
const fails = (code: string) => (error: unknown) => error instanceof AppError && error.code === code;
const now = new Date();
const future = new Date(now.getTime() + 86400000);
const entitlements = new EntitlementService({
  findSubscription: async (id) => id.startsWith('premium') ? {
    tier: 'premium', status: 'active', provider: null, productId: null,
    currentPeriodStart: now, expiresAt: future, trialEndsAt: null, updatedAt: now,
  } : null,
  findActiveGrants: async (id) => id === 'rewarded' ? [{
    feature: 'session_history_once', createdAt: now, expiresAt: future, consumedAt: null, status: 'active',
  }] : [],
});
const pair = { id: 'pair', status: 'active', memberIds: ['premium', 'free'] } as CoupleSessionRecord;
type Item = { id: string; sessionId: string; normalized_name: string; quantity: string | null; measure: string | null; sort_order: number; checked: boolean };
function shoppingFixture(members = pair.memberIds) {
  let items: Item[] = [
    { id: 'one', sessionId: 'pair', normalized_name: 'tomato', quantity: null, measure: 'g', sort_order: 0, checked: false },
    { id: 'two', sessionId: 'pair', normalized_name: 'basil', quantity: null, measure: null, sort_order: 1, checked: false },
    { id: 'old', sessionId: 'previous-pair', normalized_name: 'old', quantity: null, measure: null, sort_order: 0, checked: false },
  ];
  let commits = 0, rollbacks = 0;
  const queries: string[] = [];
  const query = (async (sql: string, args: readonly unknown[] = []) => {
    queries.push(sql);
    let rows: unknown[] = [];
    if (sql.includes('from couple_sessions')) {
      assert.ok(sql.includes("status='active'") && sql.includes('$2=any(member_ids)') && sql.includes('for update'));
      rows = members.includes(String(args[1])) ? [{ id: 'pair' }] : [];
    } else if (sql.startsWith('select')) {
      rows = items.filter((x) => x.sessionId === args[0]).sort((a, b) => a.sort_order - b.sort_order);
    } else if (sql.includes('unnest')) {
      assert.equal(args[0], 'pair');
      (args[1] as string[]).forEach((id, index) => { items.find((x) => x.id === id && x.sessionId === args[0])!.sort_order = index; });
    } else if (sql.startsWith('insert')) {
      assert.ok(sql.includes('on conflict(couple_session_id,normalized_name) do update'));
      assert.ok(sql.includes('coalesce(shared_shopping_list_items.quantity,excluded.quantity)'));
      assert.ok(sql.includes('coalesce(shared_shopping_list_items.measure,excluded.measure)'));
      const existing = items.find((x) => x.sessionId === args[0] && x.normalized_name === args[3]);
      assert.ok(existing);
      existing.quantity ??= args[4] as string | null;
      existing.measure ??= args[5] as string | null;
    } else {
      assert.ok(sql.includes('where id=$1 and couple_session_id=$2'));
      rows = items.filter((x) => x.id === args[0] && x.sessionId === args[1]);
    }
    return { rows, rowCount: rows.length };
  }) as typeof queryPostgres;
  const service = new SharedShoppingListService({
    query,
    findActivePair: async () => ({ ...pair, memberIds: members }),
    canPairUseFeature: (session, feature) => entitlements.canPairUseFeature(session, feature),
    transaction: async (task) => {
      const before = structuredClone(items);
      try { const result = await task(query); commits++; return result; }
      catch (error) { items = before; rollbacks++; throw error; }
    },
  });
  return { service, queries, state: () => ({ items, commits, rollbacks }) };
}

function historyFixture() {
  const queries: { sql: string; args: readonly unknown[] }[] = [];
  const hydrated: string[][] = [];
  const row = (id: string, ids: string[]) => ({ session_id: id, started_at: now, completed_at: now, session_status: 'completed', dish_count: ids.length, dish_ids: ids });
  const solo = row('own-solo', ['d1', 'd2', 'd3', 'd4', 'd5']);
  const paired = row('own-pair', ['d6']);
  const query = (async (sql: string, args: readonly unknown[] = []) => {
    queries.push({ sql, args });
    const isSolo = sql.includes('from solo_swipe_sessions s');
    assert.ok(sql.includes(isSolo ? 'where s.user_id=$1' : 'where $1=any(c.member_ids)'));
    if (args.length === 2) {
      assert.ok(sql.includes(isSolo ? 'and s.id=$2' : 'and c.id=$2'));
      assert.ok(!sql.includes('limit 3'));
      const candidate = isSolo ? solo : paired;
      const accessible = args[0] === 'premium' && args[1] === candidate.session_id;
      return { rows: accessible ? [candidate] : [], rowCount: accessible ? 1 : 0 };
    }
    assert.ok(sql.includes('limit 3'));
    return { rows: isSolo ? [solo, row('empty', [])] : [paired], rowCount: isSolo ? 2 : 1 };
  }) as typeof queryPostgres;
  const service = new MatchService({
    query,
    requireHistoryAccess: async (userId) => {
      if (!await entitlements.canUseFeature(userId, 'session_history')) {
        throw new AppError('Premium required', 403, 'PREMIUM_SESSION_HISTORY_REQUIRED');
      }
    },
    hydrateDishes: async (ids) => { hydrated.push(ids); return ids.map((id) => ({ id, name: id })) as any; },
  });
  return { service, queries, hydrated };
}

async function main() {
  await test('Free advanced payload rejected with 403', async () => {
    await assert.rejects(requireAdvancedFilterAccess('free', { maxCookTime: 30 }, entitlements), (e: unknown) => fails('PREMIUM_ADVANCED_FILTERS_REQUIRED')(e) && (e as AppError).statusCode === 403);
  });
  await test('Premium advanced payload allowed', () => requireAdvancedFilterAccess('premium', { effort: ['easy'] }, entitlements));
  await test('diet and exclusions remain Free', () => requireAdvancedFilterAccess('free', { diet: ['vegan'], exclusions: ['nuts'], cuisine: 'Italian', dishRegister: 'dinner' }, entitlements));
  await test('rewarded history remains Free and feature-specific', async () => {
    assert.equal(await entitlements.canUseFeature('rewarded', 'session_history'), true);
    assert.equal(await entitlements.canUseFeature('rewarded', 'advanced_filters'), false);
    assert.equal((await entitlements.getEffectiveEntitlements('rewarded')).isPremium, false);
  });
  await test('Free-only pair rejected', async () => {
    await assert.rejects(shoppingFixture(['free', 'other-free']).service.list('free'), fails('PREMIUM_SHOPPING_LIST_REQUIRED'));
  });
  await test('mixed pair allowed for both members', async () => {
    const { service } = shoppingFixture();
    for (const member of pair.memberIds) assert.equal((await service.list(member)).items.length, 2);
    assert.equal((await entitlements.getEffectiveEntitlements('free')).isPremium, false);
  });
  await test('unrelated user rejected', async () => {
    await assert.rejects(shoppingFixture().service.list('outsider'), fails('PAIR_SESSION_INACTIVE'));
  });
  await test('old-session item cannot be updated or deleted', async () => {
    const { service } = shoppingFixture();
    await assert.rejects(service.update('free', 'old', { checked: true }), fails('SHOPPING_LIST_ITEM_NOT_FOUND'));
    await assert.rejects(service.remove('free', 'old'), fails('SHOPPING_LIST_ITEM_NOT_FOUND'));
  });
  for (const [name, ids] of [['foreign', ['one', 'old']], ['missing', ['one']], ['duplicate', ['one', 'one']]] as const) {
    await test(`reorder rejects ${name} IDs and rolls back`, async () => {
      const fixture = shoppingFixture();
      await assert.rejects(fixture.service.reorder('free', ids), fails('SHOPPING_LIST_REORDER_SCOPE_MISMATCH'));
      assert.equal(fixture.state().rollbacks, 1);
      assert.equal(fixture.state().commits, 0);
      assert.equal(fixture.state().items[0].sort_order, 0);
    });
  }
  await test('valid reorder persists and returns authoritative order', async () => {
    const fixture = shoppingFixture();
    const result = await fixture.service.reorder('free', ['two', 'one']);
    assert.deepEqual(result.items.map((x) => x.id), ['two', 'one']);
    assert.deepEqual(result.items.map((x) => x.sort_order), [0, 1]);
    assert.equal(fixture.state().commits, 1);
    assert.ok(fixture.queries.some((x) => x.includes('from shared_shopping_list_items') && x.includes('for update')));
    assert.equal(fixture.state().items.find((x) => x.id === 'old')!.sort_order, 0);
  });
  await test('duplicate add upserts without losing existing measurement', async () => {
    const { service } = shoppingFixture();
    const result = await service.add('free', { name: ' Tomato ', quantity: '2', measure: 'kg' });
    assert.equal(result.items.length, 2);
    assert.equal(result.items[0].quantity, '2'); assert.equal(result.items[0].measure, 'g');
  });
  await test('Free history rejected before querying', async () => {
    const fixture = historyFixture();
    await assert.rejects(fixture.service.historyForUser('free'), fails('PREMIUM_SESSION_HISTORY_REQUIRED'));
    assert.equal(fixture.queries.length, 0);
  });
  await test('Premium history returns counts and previews, including empty sessions', async () => {
    const fixture = historyFixture();
    const result = await fixture.service.historyForUser('premium');
    assert.equal(result.solo[0].dishCount, 5); assert.equal(result.solo[0].previewDishes.length, 3);
    assert.equal('dishes' in result.solo[0], false);
    assert.equal(result.solo[1].dishCount, 0); assert.deepEqual(result.solo[1].previewDishes, []);
    assert.deepEqual(fixture.hydrated, [['d1', 'd2', 'd3', 'd6']]);
  });
  for (const [id, mode] of [['own-solo', 'solo'], ['own-pair', 'pair']]) {
    await test(`${mode} owner/member detail loads only requested session`, async () => {
      const fixture = historyFixture();
      const result = await fixture.service.historySessionForUser('premium', id);
      assert.equal(result.mode, mode);
      assert.ok(fixture.queries.every((x) => x.args[1] === id));
      assert.equal(fixture.hydrated.length, 1);
      assert.equal(result.dishes.length, mode === 'solo' ? 5 : 1);
    });
  }
  for (const id of ['own-solo', 'own-pair']) {
    await test(`another Premium user cannot access ${id}`, async () => {
      const fixture = historyFixture();
      await assert.rejects(fixture.service.historySessionForUser('premium-outsider', id), fails('SESSION_HISTORY_NOT_FOUND'));
      assert.equal(fixture.hydrated.length, 0);
    });
  }
  console.log(`PASS ${passed} focused Premium service checks`);
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
