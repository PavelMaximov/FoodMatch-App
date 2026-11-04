import assert from 'node:assert/strict';
import { supabaseConfig } from '../config/supabase';
import { CoupleSessionRecord, InvitationRecord } from '../domain/repositories/types';
import { domainRepositories as repos } from '../infrastructure/repositories/domainRepositories';
import { CoupleInvitationService } from '../modules/couples/services/coupleInvitationService';
import { CoupleService } from '../modules/couples/services/coupleService';
import { getPostgresPool } from '../shared/db/postgresClient';

async function main() {
  supabaseConfig.databaseUrl = 'postgres://test:test@127.0.0.1/test';
  const pool = getPostgresPool();
  const query = async (text: string) => ({
    rows: text.includes('select pair_key') ? [{ pair_key: 'a_b' }] : [],
    rowCount: 1,
  });
  pool.query = query as typeof pool.query;
  (pool as any).connect = async () => ({ query, release() {} });
  const sessions = new Map<string, CoupleSessionRecord>();
  const invitations = new Map<string, InvitationRecord>();
  let revision = 0;
  repos.soloSessions.findActive = async () => null;
  repos.coupleSessions.findActiveForUser = async (user) =>
    [...sessions.values()].find((s) => s.status === 'active' && s.memberIds.includes(user)) ?? null;
  repos.coupleSessions.findById = async (id) => sessions.get(id) ?? null;
  repos.coupleSessions.findByInviteCode = async () => null;
  repos.coupleSessions.create = async (input) => {
    const row: CoupleSessionRecord = {
      ...input, id: `session-${sessions.size}`, status: 'active', pairKey: null,
      preparedDeckDishIds: [], preparedDeckGeneration: 0, preparedDeckFiltersHash: null,
      preparedDeckMeta: {}, restartState: {}, pairLifecycleState: {},
      createdAt: new Date(), updatedAt: new Date(), closedAt: null,
    };
    sessions.set(row.id, row);
    return row;
  };
  repos.coupleSessions.update = async (id, patch) => Object.assign(sessions.get(id)!, patch);
  repos.coupleSessions.clearFilterStates = async () => {};
  repos.coupleSessions.upsertFilterState = async () => {};
  repos.filterPresets.findLast = async () => null;
  repos.matches.listForCouple = async () => [];
  repos.invitations.createOrRefresh = async (input) => {
    const pending = [...invitations.values()].find((i) => i.status === 'pending' &&
      i.fromUserId === input.fromUserId && i.toUserId === input.toUserId);
    const row: InvitationRecord = {
      ...input, id: pending?.id ?? `invite-${invitations.size}`,
      createdAt: pending?.createdAt ?? new Date(), updatedAt: new Date(Date.now() + ++revision),
    };
    invitations.set(row.id, row);
    return row;
  };
  repos.invitations.findForParticipant = async (id) => invitations.get(id) ?? null;
  repos.invitations.expirePending = async () => 0;
  repos.invitations.listPendingIncoming = async (user) => [...invitations.values()].filter(
    (i) => i.toUserId === user && i.status === 'pending' &&
      sessions.get(i.newCoupleSessionId!)?.status === 'active',
  );
  repos.invitations.setStatus = async (id, status) => Object.assign(invitations.get(id)!, { status });
  try {
    const couples = new CoupleService(), delivery = new CoupleInvitationService();
    const initial = await repos.coupleSessions.create({ inviteCode: 'ABC123', createdBy: 'a', memberIds: ['a', 'b'] });
    initial.pairKey = 'a_b';
    for (let round = 0; round < 3; round++) {
      const departure = await couples.markPartnerDisconnected('a');
      assert.equal(departure.status, 'needs_resync');
      const sent = await delivery.createContinueAsBeforeInvite('a');
      const received = await delivery.getPending('b');
      assert.equal(received.length, 1);
      assert.equal(received[0].id, sent.id);
      assert.equal(received[0].updatedAt, sent.updatedAt);
      assert.equal(received[0].direction, 'incoming');
      assert(sent.newCoupleSessionId && sent.newCoupleSessionId !== initial.id);
      await delivery.accept('b', sent.id);
      const active = await repos.coupleSessions.findActiveForUser('b');
      assert.deepEqual(active?.memberIds, ['a', 'b']);
      assert.deepEqual(await delivery.getPending('b'), []);
    }
    // A pending invitation holds an FK to the one-member replacement.
    repos.coupleSessions.delete = async () => { throw new Error('23503: invitation target is still referenced'); };
    await couples.markPartnerDisconnected('a');
    const abandoned = await delivery.createContinueAsBeforeInvite('a');
    const abandonedSession = abandoned.newCoupleSessionId!;
    const leave = await couples.leaveSession('a');
    assert.equal(leave.sessionDeleted, false);
    assert.equal(sessions.get(abandonedSession)?.status, 'closed');
    assert(invitations.has(abandoned.id), 'Keep the invitation and its target for history');
    assert.deepEqual(await delivery.getPending('b'), []);
    const first = await delivery.createContinueAsBeforeInvite('a');
    assert.notEqual(first.newCoupleSessionId, abandonedSession);
    const refreshed = await delivery.createContinueAsBeforeInvite('a');
    assert.equal(first.id, refreshed.id);
    assert.notEqual(first.updatedAt.getTime(), refreshed.updatedAt.getTime());
    assert.equal((await delivery.getPending('b'))[0].updatedAt, refreshed.updatedAt);
    console.log('PASS three logout/continue/accept rounds refreshed pending delivery metadata, FK-safe abandonment and retry');
  } finally {
    await pool.end();
  }
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
