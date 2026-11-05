// Exercises real services with in-memory repositories and transaction-scoped lock queues.
// No network or database writes. Live PostgreSQL coverage lives in supabase/tests.
const assert = require('node:assert/strict');
require('ts-node/register');
const { supabaseConfig } = require('../src/config/supabase');
supabaseConfig.databaseUrl = 'postgres://stub:stub@127.0.0.1/stub';
const { getPostgresPool } = require('../src/shared/db/postgresClient');
const { domainRepositories: r } = require('../src/infrastructure/repositories/domainRepositories');
const { postgresDishes } = require('../src/infrastructure/postgres/repositories/PostgresCatalogRepositories');
const { CoupleService } = require('../src/modules/couples/services/coupleService');
const { CoupleDeckService } = require('../src/modules/couples/services/coupleDeckService');
const { CoupleInvitationService } = require('../src/modules/couples/services/coupleInvitationService');
const { SwipeService } = require('../src/modules/swipes/services/swipeService');
const { updateCoupleFilterStateSchema } = require('../src/modules/couples/dto/coupleSchemas');
const pool = getPostgresPool();
const tails = new Map();
let priorPairKey = 'a_b';
let lockCount = 0, updates = 0, clears = 0, next = 0, readsOverride;
const sessions = new Map(), invites = new Map(), filters = new Map(), swipes = [];
const clone = value => structuredClone(value);
const active = async user => [...sessions.values()].find(s => s.status === 'active' && s.memberIds.includes(user)) ?? null;
async function rawQuery(sql) {
  if (sql.includes('select pair_key')) return { rows: priorPairKey ? [{ pair_key: priorPairKey }] : [], rowCount: priorPairKey ? 1 : 0 };
  return { rows: [], rowCount: 1 };
}
pool.query = rawQuery;
pool.connect = async () => {
  const held = new Map();
  return {
    async query(sql, args = []) {
      if (/pg_advisory_xact_lock|for update/.test(sql)) {
        const key = (sql.includes('advisory') ? 'user:' : sql.includes('couple_invitations') ? 'invite:' : 'session:') + args[0];
        if (!held.has(key)) {
          const prior = tails.get(key) ?? Promise.resolve();
          let release;
          const tail = new Promise(resolve => { release = resolve; });
          tails.set(key, tail);
          await prior;
          held.set(key, () => { release(); if (tails.get(key) === tail) tails.delete(key); });
          lockCount++;
        }
      }
      if (sql === 'commit' || sql === 'rollback') { for (const release of held.values()) release(); held.clear(); }
      return rawQuery(sql, args);
    },
    release() { for (const release of held.values()) release(); },
  };
};
function reset() { sessions.clear(); invites.clear(); filters.clear(); swipes.length = 0; updates = clears = 0; readsOverride = null; }
function seed(members = ['a', 'b']) {
  const s = { id: `session-${++next}`, inviteCode: `CODE${next}`, status: 'active', createdBy: members[0], memberIds: members,
    pairKey: members.length === 2 ? 'a_b' : null, preparedDeckDishIds: [], preparedDeckGeneration: 0,
    preparedDeckFiltersHash: null, preparedDeckMeta: { status: 'idle' }, restartState: {}, pairLifecycleState: {},
    createdAt: new Date(), updatedAt: new Date(), closedAt: null };
  sessions.set(s.id, s); return s;
}
r.soloSessions.findActive = async () => null;
r.coupleSessions.findActiveForUser = async u => clone(await (readsOverride ? readsOverride(u) : active(u)));
r.coupleSessions.findById = async id => clone(sessions.get(id) ?? null);
r.coupleSessions.findByInviteCode = async code => clone([...sessions.values()].find(s => s.inviteCode === code) ?? null);
r.coupleSessions.create = async input => { const s = seed(input.memberIds); Object.assign(s, input); return clone(s); };
r.coupleSessions.update = async (id, patch) => { updates++; Object.assign(sessions.get(id), patch); return clone(sessions.get(id)); };
r.coupleSessions.clearFilterStates = async id => { clears++; filters.delete(id); };
r.coupleSessions.listFilterStates = async id => clone(filters.get(id) ?? []);
r.coupleSessions.upsertFilterState = async (id, state) => {
  const values = filters.get(id) ?? []; const index = values.findIndex(s => s.userId === state.userId);
  if (index < 0) values.push(clone(state)); else values[index] = clone(state); filters.set(id, values);
};
r.filterPresets.findLast = async () => null;
r.matches.listForCouple = async () => [];
r.invitations.createOrRefresh = async input => {
  const previous = [...invites.values()].find(i => i.fromUserId === input.fromUserId && i.toUserId === input.toUserId && i.status === 'pending');
  const row = { ...input, id: previous?.id ?? `invite-${++next}`, createdAt: new Date(), updatedAt: new Date() };
  invites.set(row.id, row); return clone(row);
};
r.invitations.listPendingIncoming = async user => clone([...invites.values()].filter(i => i.toUserId === user && i.status === 'pending' && i.expiresAt > new Date() && sessions.get(i.newCoupleSessionId)?.status === 'active'));
r.invitations.findForParticipant = async (id, user) => { const i = invites.get(id); return i && [i.fromUserId, i.toUserId].includes(user) ? clone(i) : null; };
r.invitations.setStatus = async (id, status) => { Object.assign(invites.get(id), { status }); return clone(invites.get(id)); };
postgresDishes.getByPublicId = async id => ({ id, visibility: 'public', status: 'approved' });
r.swipes.createOnce = async input => { swipes.push(input); return { created: true, swipe: { ...input, id: 'swipe' } }; };
r.swipes.countLikes = async () => 1;
const couples = new CoupleService(), invitations = new CoupleInvitationService(), deck = new CoupleDeckService();
const code = expected => error => error.code === expected;
async function main() {
  reset();
  const created = await Promise.allSettled([couples.createSession('a'), couples.createSession('a')]);
  assert.equal(created.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(sessions.size, 1);
  console.log('PASS concurrent create reserves one active session');

  reset(); seed();
  const [one, two] = await Promise.all([invitations.createContinueAsBeforeInvite('a'), invitations.createContinueAsBeforeInvite('b')]);
  assert.equal(one.id, two.id); assert.equal(invites.size, 1);
  assert.equal([...sessions.values()].filter(s => s.status === 'active').length, 1);
  assert.deepEqual((await active('a')).memberIds, ['a', 'b']);
  assert.equal((await active('a')).id, (await active('b')).id);
  assert.equal(invites.get(one.id).status, 'accepted');
  const saved = filters.get(one.newCoupleSessionId);
  saved[0].filters = { selectedCategories: ['main'] };
  await invitations.accept('b', one.id);
  assert.deepEqual(filters.get(one.newCoupleSessionId), saved, 'Accept replay must not reset user choices');
  await assert.rejects(invitations.decline('b', one.id), code('INVITATION_NOT_PENDING'));
  assert.equal(invites.get(one.id).status, 'accepted');
  await assert.rejects(invitations.accept('outsider', one.id), code('INVITATION_NOT_FOUND'));
  await couples.leaveSession('a', { sessionId: one.newCoupleSessionId });
  await assert.rejects(invitations.accept('b', one.id), code('INVITATION_SESSION_INACTIVE'));
  console.log('PASS simultaneous Continue converges; retry preserves choices, decline cannot overwrite acceptance and closed sessions stay closed');

  reset(); seed(); priorPairKey = null;
  const sentWithoutPreset = await invitations.createContinueAsBeforeInvite('a');
  const acceptedWithoutPreset = await invitations.createContinueAsBeforeInvite('b');
  assert.equal(sentWithoutPreset.id, acceptedWithoutPreset.id);
  assert.equal(acceptedWithoutPreset.status, 'accepted');
  priorPairKey = 'a_b';
  console.log('PASS continuation reuses incoming invitation even before a first preset exists');

  reset(); let s = seed();
  const first = await deck.requestDeckRestart('a');
  assert.equal(first.status, 'waiting');
  const ready = await deck.requestDeckRestart('b');
  assert.equal(ready.status, 'ready');
  const count = updates, clearCount = clears;
  assert.equal((await deck.getDeckRestartStatus('a')).status, 'ready');
  assert.equal((await deck.getDeckRestartStatus('b')).status, 'ready');
  assert.equal(updates, count); assert.equal(clears, clearCount);
  await assert.rejects(couples.confirmMyFilterState('a', { sessionId: s.id, generation: 0 }), code('PAIR_FILTER_ROUND_CHANGED'));
  await couples.updateMyFilterState('b', { selectedCategories: ['main'] });
  assert.equal((await deck.getDeckRestartStatus('a')).status, 'ready', 'Saving filters must not consume the other user’s restart decision');
  assert.equal((await deck.requestDeckRestart('a')).generation, ready.generation);
  console.log('PASS restart readiness persists through polling, retries and first partner filter edits');

  reset(); seed();
  await Promise.all([deck.requestDeckRestart('a'), deck.requestDeckRestart('b')]);
  assert.equal((await deck.getDeckRestartStatus('a')).status, 'ready'); assert.equal(clears, 1);
  console.log('PASS concurrent restart retains both votes and clears filters once');

  reset(); const old = seed(), replacement = seed(); let calls = 0;
  readsOverride = async () => ++calls === 1 ? old : replacement;
  await assert.rejects(couples.updateMyFilterState('a', { selectedCategories: ['main'] }), code('PAIR_SESSION_CHANGED'));
  assert.equal(updates, 0); assert.equal(filters.size, 0);
  readsOverride = null; sessions.delete(old.id);
  await assert.rejects(couples.updateMyFilterState('a', {}, { sessionId: old.id }), code('PAIR_SESSION_CHANGED'));
  replacement.pairLifecycleState = { generation: 2 };
  await assert.rejects(couples.confirmMyFilterState('a', { sessionId: replacement.id, generation: 1 }), code('PAIR_FILTER_ROUND_CHANGED'));
  assert.equal(filters.size, 0);
  console.log('PASS session replacement during lock and stale session/round payloads cannot write filters');

  reset(); s = seed(); const swiping = new SwipeService();
  await assert.rejects(swiping.createSwipe('a', 'dish', 'like', s.id), code('PAIR_DECK_NOT_READY'));
  s.preparedDeckMeta.status = 'ready'; s.preparedDeckDishIds = ['dish']; s.pairLifecycleState.status = 'needs_resync';
  await assert.rejects(swiping.createSwipe('a', 'dish', 'like', s.id), code('PAIR_DECK_NOT_READY'));
  s.pairLifecycleState.status = 'active';
  await assert.rejects(swiping.createSwipe('a', 'other-dish', 'like', s.id), code('DISH_NOT_IN_PAIR_DECK'));
  s.memberIds = ['a'];
  await assert.rejects(swiping.createSwipe('a', 'dish', 'like', s.id), code('PAIR_DECK_NOT_READY'));
  assert.equal(swipes.length, 0);
  s.memberIds = ['a','b'];
  await swiping.createSwipe('a', 'dish', 'like', s.id); assert.equal(swipes.length, 1);
  console.log('PASS only ready two-member decks accept their own dishes');

  const sessionId = '11111111-1111-4111-8111-111111111111';
  for (const body of [{ selectedCategories: ['main'], sessionId, generation: 4 }, { choices: { selectedCategories: ['main'] }, sessionId, generation: 4 }]) {
    const parsed = updateCoupleFilterStateSchema.parse(body);
    assert.equal(parsed.sessionId, sessionId); assert.equal(parsed.generation, 4);
  }
  assert(lockCount > 0);
  console.log('PASS HTTP filter normalization preserves session and generation guards');
}
main().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => pool.end());
