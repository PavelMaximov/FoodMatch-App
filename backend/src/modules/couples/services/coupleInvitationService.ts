import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { LastFilterPresetModel } from '../../filters/models/LastFilterPreset';
import { buildPairKey } from '../../filters/services/lastFilterPresetService';
import { MatchModel } from '../../matches/models/Match';
import { UserModel } from '../../users/models/User';
import { CoupleInvitationDocument, CoupleInvitationModel } from '../models/CoupleInvitation';
import { CoupleFilterUserChoice, CoupleSessionDocument, CoupleSessionModel } from '../models/CoupleSession';
import { clearPreparedDeck } from './coupleDeckService';
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
      { fromUserId, toUserId, pairKey, status: 'pending' },
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
        { fromUserId: objectId, status: { $in: ['pending', 'accepted', 'declined', 'expired'] } }
      ]
    })
      .sort({ updatedAt: -1 })
      .limit(20);
    return Promise.all(invites.map((invite) => this.toDto(invite, userId)));
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
      await session.save();
    }
    await this.applyPreviousChoices(session, invite);
    invite.status = 'accepted';
    await invite.save();
    return { invite: await this.toDto(invite, userId), session: await this.coupleService.getMyActiveSession(userId) };
  }

  private async applyPreviousChoices(
    session: CoupleSessionDocument,
    invite: CoupleInvitationDocument
  ) {
    const memberIds = session.members.map((memberId) => memberId.toString());
    const presets = await LastFilterPresetModel.find({
      mode: 'paired',
      pairKey: invite.pairKey,
      userId: { $in: session.members }
    }).lean();
    const presetByUserId = new Map(
      presets.map((preset) => [preset.userId?.toString() ?? '', preset])
    );
    const previousSession = invite.previousCoupleSessionId
      ? await CoupleSessionModel.findById(invite.previousCoupleSessionId).lean()
      : null;
    const previousChoiceByUserId = new Map(
      (previousSession?.filterState?.users ?? []).map((choice) => [
        choice.userId.toString(),
        choice
      ])
    );
    const now = new Date();
    const users: CoupleFilterUserChoice[] = memberIds.map((memberId) => {
      const preset = presetByUserId.get(memberId);
      const previous = previousChoiceByUserId.get(memberId);
      return {
        userId: new Types.ObjectId(memberId),
        dishRegisters: normalizeList(preset?.dishRegisters ?? previous?.dishRegisters),
        includeCustomDishesFirst: preset
          ? preset.includeCustomDishesFirst === true
          : previous?.includeCustomDishesFirst === true,
        cuisines: normalizeList(preset?.cuisines ?? previous?.cuisines),
        moods: normalizeList(preset?.moods ?? previous?.moods),
        diet: normalizeList(preset?.diet ?? previous?.diet),
        exclusions: normalizeList(preset?.exclusions ?? previous?.exclusions),
        confirmed: true,
        updatedAt: now
      };
    });
    session.filterState = { users, status: 'ready', updatedAt: now };
    session.pairLifecycleState = {
      status: 'active',
      reason: null,
      changedBy: null,
      generation: session.pairLifecycleState?.generation ?? 0,
      updatedAt: now
    };
    session.restartState = {
      requestedBy: [],
      status: 'idle',
      generation: session.restartState?.generation ?? 0,
      updatedAt: now
    };
    clearPreparedDeck(session);
    await session.save();
    console.log(
      `[PairInvitation] accepted previous choices session=${session.id} ` +
        `members=${users.length} bothConfirmed=${users.length >= 2}`
    );
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

function normalizeList(values?: string[]) {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.map((value) => (value ?? '').trim().toLowerCase()).filter(Boolean))];
}
