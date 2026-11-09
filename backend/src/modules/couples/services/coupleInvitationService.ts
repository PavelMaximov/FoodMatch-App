import { lockSessionUsers } from './pairSessionGuard';
import { AppError } from '../../../core/errors/AppError';
import { InvitationRecord } from '../../../domain/repositories/types';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import {
  queryPostgres,
  withPostgresTransaction,
} from '../../../shared/db/postgresClient';
import { buildPairKey } from '../../filters/services/lastFilterPresetService';
import { CoupleService } from './coupleService';
const TTL = 20 * 60 * 1000;
export class CoupleInvitationService {
  private couples = new CoupleService();
  async createContinueAsBeforeInvite(userId: string) {
    // Resolve the partner before taking ordered locks; recheck inside the transaction.
    const current = await domainRepositories.coupleSessions.findActiveForUser(userId);
    const prior = current && current.memberIds.length === 2 ? null : await queryPostgres<{ pair_key: string }>(
      "select pair_key from filter_presets where user_id=$1 and mode='paired' and pair_key is not null order by used_at desc nulls last limit 1", [userId],
    );
    const pending = await domainRepositories.invitations.listPendingIncoming(userId);
    const pairKey = current && current.memberIds.length === 2
      ? (current.pairKey ?? buildPairKey(current.memberIds)) : prior?.rows[0]?.pair_key ?? pending[0]?.pairKey;
    const partner = pairKey?.split('_').find((id) => id !== userId);
    if (!partner) throw new AppError('No previous pair setup found.', 404, 'PREVIOUS_PARTNER_NOT_FOUND');
    return withPostgresTransaction(async () => {
      await lockSessionUsers([userId, partner]);
      const active = await domainRepositories.coupleSessions.findActiveForUser(userId);
      if (active && active.memberIds.length === 2 && !active.memberIds.includes(partner))
        throw new AppError('This pair session has changed.', 409, 'PAIR_SESSION_CHANGED');
      const incoming = (await domainRepositories.invitations.listPendingIncoming(userId))
        .find((i) => i.fromUserId === partner && i.pairKey === pairKey);
      if (incoming) {
        // Both users chose Continue. Reuse the first request instead of creating a cross-invite.
        await this.lockInvitation(incoming.id, incoming.newCoupleSessionId);
        const accepted = await this.acceptLocked(userId, incoming.id);
        return accepted.invite;
      }
      return this.createContinueLocked(userId, pairKey!, partner);
    });
  }
  private async createContinueLocked(userId: string, pairKey: string, partner: string) {
    let active = await domainRepositories.coupleSessions.findActiveForUser(userId);
    const preset = await domainRepositories.filterPresets.findLast(userId, 'paired', pairKey);
    const previous = active ?? null;
    if (!active || active.memberIds.length > 1) {
      if (active) await this.couples.closeActiveSession(userId);
      await this.couples.createSession(userId);
      active =
        await domainRepositories.coupleSessions.findActiveForUser(userId);
    }
    if (!active)
      throw new AppError(
        'Could not create continuation session.',
        500,
        'CONTINUATION_SESSION_CREATE_FAILED',
      );
    const matches = previous
      ? await domainRepositories.matches.listForCouple(previous.id)
      : [];
    const f = preset?.filters as any;
    const invite = await domainRepositories.invitations.createOrRefresh({
      fromUserId: userId,
      toUserId: partner,
      pairKey,
      previousCoupleSessionId: previous?.id ?? null,
      newCoupleSessionId: active.id,
      previousFilterPresetId: preset?.id ?? null,
      status: 'pending',
      matchedLastTime: f?.matchedLastTime ?? 0,
      mutualMatchCount: matches.length,
      expiresAt: new Date(Date.now() + TTL),
    });
    return this.dto(invite, userId);
  }
  async getPending(userId: string) {
    await domainRepositories.invitations.expirePending();
    return Promise.all(
      (await domainRepositories.invitations.listPendingIncoming(userId)).map(
        (x) => this.dto(x, userId),
      ),
    );
  }
  async getInvitationStatus(userId: string, id: string) {
    const i = await domainRepositories.invitations.findForParticipant(
      id,
      userId,
    );
    if (!i)
      throw new AppError('Invitation not found.', 404, 'INVITATION_NOT_FOUND');
    return this.dto(i, userId);
  }
  async accept(userId: string, id: string) {
    return withPostgresTransaction(async () => {
      const invite = await this.target(userId, id);
      await lockSessionUsers([invite.fromUserId, invite.toUserId]);
      await this.lockInvitation(id, invite.newCoupleSessionId);
      return this.acceptLocked(userId, id);
    });
  }
  private async lockInvitation(id: string, sessionId: string | null) {
    await queryPostgres('select id from couple_invitations where id=$1 for update', [id]);
    await queryPostgres('select id from couple_sessions where id=$1 for update', [sessionId]);
  }
  private async acceptLocked(userId: string, id: string) {
    const i = await this.target(userId, id);
    if (i.status === 'accepted') {
      const active = await domainRepositories.coupleSessions.findActiveForUser(userId);
      if (!active || active.id !== i.newCoupleSessionId || !active.memberIds.includes(i.fromUserId))
        throw new AppError('Invitation session is no longer active.', 409, 'INVITATION_SESSION_INACTIVE');
      return { invite: await this.dto(i, userId), session: await this.couples.getMyActiveSession(userId) };
    }
    if (i.status !== 'pending') throw new AppError('Invitation is no longer pending.', 409, 'INVITATION_NOT_PENDING');
    if (i.expiresAt <= new Date()) {
      await domainRepositories.invitations.setStatus(id, 'expired');
      throw new AppError('Invitation expired.', 409, 'INVITATION_EXPIRED');
    }
    const s = i.newCoupleSessionId
      ? await domainRepositories.coupleSessions.findById(i.newCoupleSessionId)
      : null;
    if (!s || s.status !== 'active')
      throw new AppError(
        'Invitation expired.',
        404,
        'INVITATION_SESSION_INACTIVE',
      );
    if (!s.memberIds.includes(userId) && s.memberIds.length >= 2)
      throw new AppError('This session is already full.', 409, 'SESSION_FULL');
    if (await domainRepositories.soloSessions.findActive(userId))
      throw new AppError(
        'Please leave your solo session first.',
        409,
        'ACTIVE_SOLO_SESSION_EXISTS',
      );
    const current =
      await domainRepositories.coupleSessions.findActiveForUser(userId);
    if (current && current.id !== s.id)
      throw new AppError(
        'Please leave your current session before joining another one.',
        409,
        'ACTIVE_SESSION_HAS_PARTNER',
      );
    if (!s.memberIds.includes(userId)) {
      const members = [...s.memberIds, userId];
      await domainRepositories.coupleSessions.update(s.id, {
        memberIds: members,
        pairKey: buildPairKey(members),
        preparedDeckDishIds: [],
        preparedDeckMeta: { status: 'idle' },
      });
    }
    for (const member of new Set([...s.memberIds, userId])) {
      const p = await domainRepositories.filterPresets.findLast(
        member,
        'paired',
        i.pairKey,
      );
      await domainRepositories.coupleSessions.upsertFilterState(s.id, {
        userId: member,
        filters: p?.filters ?? {},
        confirmed: true,
        confirmedAt: new Date(),
      });
    }
    const accepted = await domainRepositories.invitations.setStatus(
      id,
      'accepted',
    );
    return {
      invite: await this.dto(accepted!, userId),
      session: await this.couples.getMyActiveSession(userId),
    };
  }
  async decline(userId: string, id: string) {
    return withPostgresTransaction(async () => {
      const before = await this.target(userId, id);
      await lockSessionUsers([before.fromUserId, before.toUserId]);
      await this.lockInvitation(id, before.newCoupleSessionId);
      const i = await this.target(userId, id);
      if (i.status === 'declined') return this.dto(i, userId);
      if (i.status !== 'pending') throw new AppError('Invitation is no longer pending.', 409, 'INVITATION_NOT_PENDING');
      return this.dto((await domainRepositories.invitations.setStatus(id, 'declined'))!, userId);
    });
  }
  private async target(u: string, id: string) {
    const i = await domainRepositories.invitations.findForParticipant(id, u);
    if (!i || i.toUserId !== u)
      throw new AppError('Invitation not found.', 404, 'INVITATION_NOT_FOUND');
    return i;
  }
  private async dto(i: InvitationRecord, u: string) {
    const profiles = await queryPostgres<any>(
        'select id,display_name,email,avatar_url from profiles where id=any($1::uuid[])',
        [[i.fromUserId, i.toUserId]],
      ),
      by = new Map(profiles.rows.map((p) => [p.id, p])),
      user = (id: string) => {
        const p = by.get(id);
        return {
          id,
          displayName: p?.display_name ?? p?.email?.split('@')[0] ?? 'Partner',
          avatarUrl: p?.avatar_url ?? null,
        };
      };
    const s = i.newCoupleSessionId
      ? await domainRepositories.coupleSessions.findById(i.newCoupleSessionId)
      : null;
    return {
      id: i.id,
      fromUserId: i.fromUserId,
      toUserId: i.toUserId,
      direction: i.fromUserId === u ? 'outgoing' : 'incoming',
      pairKey: i.pairKey,
      previousCoupleSessionId: i.previousCoupleSessionId,
      newCoupleSessionId: i.newCoupleSessionId,
      status: i.status,
      mode: 'paired',
      matchedLastTime: i.matchedLastTime,
      mutualMatchCount: i.mutualMatchCount,
      previousFilterPresetId: i.previousFilterPresetId,
      createdAt: i.createdAt,
      updatedAt: i.updatedAt,
      expiresAt: i.expiresAt,
      sessionActive: s?.status === 'active',
      fromUser: user(i.fromUserId),
      toUser: user(i.toUserId),
    };
  }
}
