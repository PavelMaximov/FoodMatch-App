import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { LastFilterPresetModel } from '../../filters/models/LastFilterPreset';
import { buildPairKey } from '../../filters/services/lastFilterPresetService';
import { MatchModel } from '../../matches/models/Match';
import { UserModel } from '../../users/models/User';
import { CoupleSessionModel } from '../models/CoupleSession';
import { CoupleInvitationDocument, CoupleInvitationModel } from '../models/CoupleInvitation';
import { CoupleService } from './coupleService';

const INVITE_TTL_MS = 20 * 60 * 1000;

export class CoupleInvitationService {
  private coupleService = new CoupleService();

  async createContinueAsBeforeInvite(userId: string) {
    const fromUserId = new Types.ObjectId(userId);
    const activeSession = await CoupleSessionModel.findOne({ members: fromUserId, status: 'active' }).sort({ updatedAt: -1, createdAt: -1 });
    const activePartnerId = activeSession?.members.find((memberId) => memberId.toString() !== userId) ?? null;
    const lastPreset = await LastFilterPresetModel.findOne({
      mode: 'paired',
      userId: fromUserId,
      pairKey: { $type: 'string', $ne: null }
    })
      .sort({ usedAt: -1, updatedAt: -1 })
      .lean();

    const pairKey = activeSession?.members.length && activeSession.members.length >= 2
      ? buildPairKey(activeSession.members.map((memberId) => memberId.toString()))
      : lastPreset?.pairKey;
    if (!pairKey) throw new AppError('No previous pair setup found.', 404, 'PREVIOUS_PARTNER_NOT_FOUND');

    const partnerId = activePartnerId?.toString() ?? pairKey.split('_').find((memberId) => memberId !== userId);
    if (!partnerId || !Types.ObjectId.isValid(partnerId) || partnerId === userId) {
      throw new AppError('No previous pair setup found.', 404, 'PREVIOUS_PARTNER_NOT_FOUND');
    }

    if (activeSession?.pairLifecycleState?.status === 'partner_action_required') {
      throw new AppError('Pair filter change is already in progress.', 409, 'PAIR_FILTER_CHANGE_IN_PROGRESS');
    }
    if (activeSession?.restartState?.status === 'waiting' || activeSession?.restartState?.status === 'ready') {
      throw new AppError('Pair restart is already in progress.', 409, 'PAIR_RESTART_IN_PROGRESS');
    }

    await this.expireOldInvites();
    const existingRound = await CoupleInvitationModel.findOne({
      pairKey,
      status: { $in: ['pending', 'accepted'] },
      expiresAt: { $gt: new Date() }
    }).sort({ updatedAt: -1, createdAt: -1 });
    if (existingRound) {
      if (existingRound.status === 'pending' && existingRound.toUserId.toString() === userId) {
        const accepted = await this.accept(userId, existingRound.id);
        return accepted.invite;
      }
      console.log(`[PairInvitation] reused continuation round pairKey=${pairKey} status=${existingRound.status}`);
      return this.toDto(existingRound, userId);
    }

    const previousSession = activeSession && activePartnerId
      ? activeSession
      : await CoupleSessionModel.findOne({ members: { $all: [fromUserId, new Types.ObjectId(partnerId)] } })
          .sort({ updatedAt: -1, createdAt: -1 });
    const mutualMatchCount = previousSession ? await MatchModel.countDocuments({ coupleId: previousSession._id }) : null;

    let session = activeSession && activeSession.members.length === 1 ? activeSession : activeSession && activePartnerId ? activeSession : null;
    if (!session) {
      const createdSession = await this.coupleService.createSession(userId);
      session = await CoupleSessionModel.findById(createdSession?._id ?? createdSession?.id);
    }
    if (!session) throw new AppError('Could not create continuation session.', 500, 'CONTINUATION_SESSION_CREATE_FAILED');

    const toUserId = new Types.ObjectId(partnerId);
    const expiresAt = new Date(Date.now() + INVITE_TTL_MS);
    const invite = await CoupleInvitationModel.findOneAndUpdate(
      { pairKey, status: 'pending' },
      {
        $set: {
          previousCoupleSessionId: previousSession?._id ?? null,
          newCoupleSessionId: session._id,
          mode: 'paired',
          matchedLastTime: lastPreset?.matchedLastTime ?? null,
          mutualMatchCount,
          previousFilterPresetId: lastPreset?._id ?? null,
          expiresAt
        },
        $setOnInsert: { fromUserId, toUserId, pairKey, status: 'pending' }
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
    return this.toDto(invite, userId);
  }

  async getPending(userId: string) {
    await this.expireOldInvites();
    const objectId = new Types.ObjectId(userId);
    const invites = await CoupleInvitationModel.find({
      $or: [
        { toUserId: objectId, status: 'pending', expiresAt: { $gt: new Date() } },
        { toUserId: objectId, status: 'accepted' },
        { fromUserId: objectId, status: { $in: ['pending', 'accepted', 'declined', 'expired'] } }
      ]
    })
      .sort({ updatedAt: -1 })
      .limit(20);
    const activeSession = await CoupleSessionModel.findOne({ members: objectId, status: 'active' }).sort({ updatedAt: -1, createdAt: -1 });
    const suppressPending = activeSession?.pairLifecycleState?.status === 'partner_action_required' ||
      activeSession?.pairLifecycleState?.status === 'filter_change_pending' ||
      activeSession?.restartState?.status === 'waiting' ||
      activeSession?.restartState?.status === 'ready';
    const visibleInvites = suppressPending
      ? invites.filter((invite) => invite.status === 'accepted')
      : invites;
    if (suppressPending && visibleInvites.length !== invites.length) {
      console.log('[PairInvitation] suppressed stale/same-round invite reason=active_pair_round');
    }
    return Promise.all(visibleInvites.map((invite) => this.toDto(invite, userId)));
  }

  async accept(userId: string, inviteId: string) {
    const invite = await this.requireInviteForTarget(userId, inviteId);
    if (invite.expiresAt.getTime() <= Date.now()) {
      invite.status = 'expired';
      await invite.save();
      throw new AppError('Invitation expired.', 409, 'INVITATION_EXPIRED');
    }
    const session = await CoupleSessionModel.findById(invite.newCoupleSessionId ?? invite.previousCoupleSessionId);
    if (!session || session.status !== 'active') throw new AppError('Invitation expired.', 404, 'INVITATION_SESSION_INACTIVE');
    const userObjectId = new Types.ObjectId(userId);
    const alreadyMember = session.members.some((memberId) => memberId.toString() === userId);
    if (!alreadyMember) {
      const active = await CoupleSessionModel.findOne({ members: userObjectId, status: 'active' }).sort({ updatedAt: -1, createdAt: -1 });
      if (active && active.id !== session.id) throw new AppError('Please leave your current session before joining another one.', 409, 'ACTIVE_SESSION_HAS_PARTNER');
      session.members.push(userObjectId);
    }
    const now = new Date();
    this.coupleService.startPairRoundOnSession(session, {
      reason: 'continuation',
      requestedBy: userId,
      requiresPartnerAction: false,
      resetPreparedDeck: true,
      resetFilterConfirmations: true,
      incrementGeneration: false,
      now
    });
    await session.save();
    await CoupleInvitationModel.updateMany(
      { pairKey: invite.pairKey, status: 'pending', _id: { $ne: invite._id } },
      { $set: { status: 'cancelled' } }
    );
    invite.status = 'accepted';
    await invite.save();
    return { invite: await this.toDto(invite, userId), session: await this.coupleService.getMyActiveSession(userId) };
  }

  async decline(userId: string, inviteId: string) {
    const invite = await this.requireInviteForTarget(userId, inviteId);
    invite.status = 'declined';
    await invite.save();
    return this.toDto(invite, userId);
  }

  private async requireInviteForTarget(userId: string, inviteId: string) {
    if (!Types.ObjectId.isValid(inviteId)) throw new AppError('Invitation not found.', 404, 'INVITATION_NOT_FOUND');
    const invite = await CoupleInvitationModel.findOne({ _id: inviteId, toUserId: new Types.ObjectId(userId), status: 'pending' });
    if (!invite) throw new AppError('Invitation not found.', 404, 'INVITATION_NOT_FOUND');
    return invite;
  }

  private async expireOldInvites() {
    await CoupleInvitationModel.updateMany({ status: 'pending', expiresAt: { $lte: new Date() } }, { $set: { status: 'expired' } });
  }

  private async toDto(invite: CoupleInvitationDocument, viewerUserId: string) {
    const from = await UserModel.findById(invite.fromUserId).select('displayName email avatarUrl').lean();
    const to = await UserModel.findById(invite.toUserId).select('displayName email avatarUrl').lean();
    return {
      id: invite.id,
      fromUserId: invite.fromUserId.toString(),
      toUserId: invite.toUserId.toString(),
      direction: invite.fromUserId.toString() === viewerUserId ? 'outgoing' : 'incoming',
      pairKey: invite.pairKey,
      previousCoupleSessionId: invite.previousCoupleSessionId?.toString() ?? null,
      newCoupleSessionId: invite.newCoupleSessionId?.toString() ?? null,
      status: invite.status,
      mode: invite.mode,
      matchedLastTime: invite.matchedLastTime ?? null,
      mutualMatchCount: invite.mutualMatchCount ?? null,
      previousFilterPresetId: invite.previousFilterPresetId?.toString() ?? null,
      createdAt: invite.createdAt,
      expiresAt: invite.expiresAt,
      fromUser: this.userDto(from, invite.fromUserId.toString()),
      toUser: this.userDto(to, invite.toUserId.toString())
    };
  }

  private userDto(user: { displayName?: string; email?: string; avatarUrl?: string } | null, id: string) {
    return {
      id,
      displayName: user?.displayName ?? user?.email?.split('@')[0] ?? 'Partner',
      avatarUrl: user?.avatarUrl ?? null
    };
  }
}
