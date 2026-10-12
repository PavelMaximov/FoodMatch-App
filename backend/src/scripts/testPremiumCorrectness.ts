import assert from 'node:assert/strict';
import { Pool, PoolClient } from 'pg';
import { AppError } from '../core/errors/AppError';
import { domainRepositories } from '../infrastructure/repositories/domainRepositories';
import { queryPostgres, withPostgresAdvisoryLock } from '../shared/db/postgresClient';
import { CoupleSessionRecord } from '../domain/repositories/types';
import { CoupleService } from '../modules/couples/services/coupleService';
import { MatchService } from '../modules/matches/services/matchService';
import { MatchController } from '../modules/matches/controllers/matchController';
import { DishService } from '../modules/dishes/services/dishService';
import { EntitlementService } from '../modules/entitlements/services/entitlementService';
import { AuthRequest } from '../core/middleware/authMiddleware';
import { Response } from 'express';

const now = new Date();
const premium = new EntitlementService().compute({
  tier: 'premium', status: 'active', provider: null, productId: null,
  currentPeriodStart: now, expiresAt: new Date(now.getTime() + 86400000), trialEndsAt: null, updatedAt: now,
});
const free = new EntitlementService().compute(null);

async function testLeaveHistory() {
  const sessions = domainRepositories.coupleSessions;
  const swipes = domainRepositories.swipes;
  const matches = domainRepositories.matches;
  const originals = [sessions.findActiveForUser, sessions.update, sessions.clearFilterStates, sessions.delete,
    swipes.deleteForSession, matches.deleteForCouple, matches.listForCouple] as const;
  const session = {
    id: 'pair-ab', status: 'active', memberIds: ['A', 'B'], pairKey: 'A_B',
    preparedDeckDishIds: ['dish'], preparedDeckFiltersHash: 'hash', preparedDeckMeta: {status: 'ready'},
    restartState: {status: 'waiting'}, pairLifecycleState: {status: 'needs_resync'},
    createdAt: now, closedAt: null,
  } as unknown as CoupleSessionRecord;
  const mutualMatches = [{ dishId: 'dish', coupleSessionId: session.id }];
  const pairedSwipes = ['A-like-dish', 'B-like-dish'];
  let filters = ['A-filters', 'B-filters'];
  let deleted = false, currentMatchReads = 0;
  try {
    sessions.findActiveForUser = async (user) => session.status === 'active' && session.memberIds.includes(user) ? session : null;
    sessions.update = async (_id, patch) => { Object.assign(session, patch); return session; };
    sessions.clearFilterStates = async () => { filters = []; };
    sessions.delete = async () => { deleted = true; };
    swipes.deleteForSession = async () => { throw Error('Leave must preserve paired swipes'); };
    matches.deleteForCouple = async () => { throw Error('Leave must preserve mutual matches'); };
    matches.listForCouple = async () => { currentMatchReads++; return []; };
    await new CoupleService().leaveSession('A');
    assert.equal(session.status, 'closed'); assert.ok(session.closedAt instanceof Date);
    assert.deepEqual(session.memberIds, ['A', 'B']); assert.equal(session.pairKey, 'A_B');
    assert.equal(mutualMatches.length, 1); assert.equal(pairedSwipes.length, 2);
    assert.deepEqual(session.preparedDeckDishIds, []); assert.equal(session.preparedDeckFiltersHash, null);
    assert.equal(session.restartState.status, 'idle'); assert.equal(session.pairLifecycleState.status, 'idle');
    assert.deepEqual(filters, []); assert.equal(deleted, false);
    const history = new MatchService({
      requireHistoryAccess: async () => {}, // All three are Premium; membership still matters.
      query: (async (sql: string, values: readonly unknown[] = []) => {
        if (sql.includes('from solo_swipe_sessions')) return {rows: [], rowCount: 0};
        assert.ok(sql.includes('where $1=any(c.member_ids)') && sql.includes('and c.id=$2'));
        const allowed = session.memberIds.includes(String(values[0])) && values[1] === session.id;
        const rows = allowed ? [{session_id: session.id, started_at: now, completed_at: session.closedAt,
          session_status: session.status, dish_count: mutualMatches.length, dish_ids: mutualMatches.map((match) => match.dishId)}] : [];
        return {rows, rowCount: rows.length};
      }) as typeof queryPostgres,
      hydrateDishes: async (ids) => ids.map((id) => ({id, name: id})) as any,
    });
    for (const member of ['A', 'B']) {
      const detail = await history.historySessionForUser(member, session.id);
      assert.equal(detail.status, 'closed'); assert.equal(detail.dishCount, 1); assert.equal(detail.dishes.length, 1);
    }
    await assert.rejects(history.historySessionForUser('C', session.id),
      (error: unknown) => error instanceof AppError && error.code === 'SESSION_HISTORY_NOT_FOUND');
    for (const member of ['A', 'B']) {
      await assert.rejects(new MatchController().list({user: {id: member}} as AuthRequest, {} as Response),
        (error: unknown) => error instanceof AppError && error.statusCode === 404);
    }
    assert.equal(currentMatchReads, 0, 'Current Matches must not query a closed pair');
    assert.deepEqual(await new CoupleService().leaveSession('A'), {message: 'No active session', alreadyLeft: true});
    // Waiting abandonment is still allowed to delete its never-paired session.
    session.status = 'active'; session.memberIds = ['A'];
    await new CoupleService().leaveSession('A'); assert.equal(deleted, true);
    console.log('PASS pair leave preserves membership/swipes/matches, both former members can access history, outsiders/current Matches cannot; waiting abandonment retained');
  } finally {
    [sessions.findActiveForUser, sessions.update, sessions.clearFilterStates, sessions.delete,
      swipes.deleteForSession, matches.deleteForCouple, matches.listForCouple] = originals;
  }
}

async function testCustomDishConcurrency(isPremium: boolean) {
  const queues = new Map<string, Promise<void>>();
  let count = isPremium ? 3 : 2, locked = false, resolutions = 0;
  const query = (async () => { throw Error('Unexpected raw query in injected repository'); }) as typeof queryPostgres;
  const lock: typeof withPostgresAdvisoryLock = async (key, task) => {
    assert.equal(key, 'custom-dish-limit:user');
    const previous = queues.get(key) ?? Promise.resolve();
    let unlock!: () => void;
    const current = new Promise<void>((resolve) => { unlock = resolve; });
    queues.set(key, current);
    await previous;
    locked = true;
    try { return await task(query); }
    finally { locked = false; unlock(); }
  };
  const service = new DishService({
    withLock: lock,
    entitlements: (clientQuery) => {
      assert.equal(clientQuery, query);
      return {getEffectiveEntitlements: async () => { assert.ok(locked); resolutions++; return isPremium ? premium : free; }};
    },
    dishes: (clientQuery) => {
      assert.equal(clientQuery, query);
      return {
        countMyCustomDishes: async () => { assert.ok(locked); await new Promise<void>((resolve) => setImmediate(resolve)); return count; },
        createCustomDish: async () => { assert.ok(locked); await new Promise<void>((resolve) => setImmediate(resolve)); count++; return {_id: 'dish', id: 'dish', name: 'Dish'}; },
      };
    },
  });
  const input = {name: 'Dish', cuisine: '', mood: [], dishRegister: 'dinner', ingredients: [], cookTime: 0, servings: '', steps: []};
  const outcomes = await Promise.allSettled([service.createCustomDish('user', input), service.createCustomDish('user', input)]);
  assert.equal(resolutions, 2, 'Each attempt resolves authoritative access inside the lock');
  assert.equal(outcomes.filter((x) => x.status === 'fulfilled').length, isPremium ? 2 : 1);
  if (!isPremium) {
    const rejected = outcomes.find((x) => x.status === 'rejected') as PromiseRejectedResult;
    assert.ok(rejected.reason instanceof AppError); assert.equal(rejected.reason.code, 'PREMIUM_CUSTOM_DISH_LIMIT');
    assert.equal(rejected.reason.statusCode, 403); assert.equal(count, 3);
  } else assert.equal(count, 5);
  console.log(`PASS concurrent ${isPremium ? 'Premium creation remains unlimited' : 'Free creation: one success, one PREMIUM_CUSTOM_DISH_LIMIT, final count 3'}`);
}

async function testLockTransactionClient() {
  const calls: Array<[string, unknown[]]> = [];
  const client = {
    query: async (sql: string, args: unknown[] = []) => { calls.push([sql, args]); return {rows: [], rowCount: 0}; },
    release: () => { calls.push(['release', []]); },
  } as unknown as PoolClient;
  const pool = {connect: async () => client} as Pick<Pool, 'connect'>;
  const result = await withPostgresAdvisoryLock('custom-dish-limit:user', async (query) => {
    await query('select task'); return 'created';
  }, pool);
  assert.equal(result, 'created');
  assert.deepEqual(calls, [['begin', []], ['select pg_advisory_xact_lock(hashtext($1))', ['custom-dish-limit:user']],
    ['select task', []], ['commit', []], ['release', []]]);
  calls.length = 0;
  await assert.rejects(withPostgresAdvisoryLock('custom-dish-limit:user', async () => { throw Error('creation failed'); }, pool));
  assert.deepEqual(calls.map(([sql]) => sql), ['begin', 'select pg_advisory_xact_lock(hashtext($1))', 'rollback', 'release']);
  console.log('PASS advisory lock uses one transaction client and commits/rolls back/releases correctly');
}

export async function testPremiumCorrectness() {
  await testLockTransactionClient();
  await testLeaveHistory();
  await testCustomDishConcurrency(false);
  await testCustomDishConcurrency(true);
}
