import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { LastFilterPresetModel } from '../../filters/models/LastFilterPreset';
import { buildPairKey } from '../../filters/services/lastFilterPresetService';
import { UserModel } from '../../users/models/User';
import { CoupleSessionModel } from '../models/CoupleSession';
import { CoupleInvitationDocument, CoupleInvitationModel } from '../models/CoupleInvitation';
import { CoupleService } from './coupleService';

const INVITE_TTL_MS = 20 * 60 * 1000;

export class CoupleInvitationService {
  private coupleService = new CoupleService();

  async createContinueAsBeforeInvite(userId: string) {
    const fromUserId = new Types.ObjectId(userId);
    const session = await CoupleSessionModel.findOne({ members: fromUserId, status: 'active' }).sort({ updatedAt: -1, createdAt: -1 });
    if (!session || session.members.length < 2) throw new AppError('No previous partner available.', 404, 'NO_PREVIOUS_PARTNER');
    const toUserId = session.members.find((memberId) => memberId.toString() !== userId);
    if (!toUserId) throw new AppError('No previous partner available.', 404, 'NO_PREVIOUS_PARTNER');
    const pairKey = buildPairKey(session.members.map((memberId) => memberId.toString()));
    const preset = await LastFilterPresetModel.findOne({ mode: 'paired', userId: fromUserId, pairKey }).lean();
    const expiresAt = new Date(Date.now() + INVITE_TTL_MS);
    const invite = await CoupleInvitationModel.findOneAndUpdate(
      { fromUserId, toUserId, pairKey, status: 'pending' },
      {
        $set: {
          previousCoupleSessionId: session._id,
          newCoupleSessionId: session._id,
          mode: 'paired',
          matchedLastTime: preset?.matchedLastTime ?? null,
          previousFilterPresetId: preset?._id ?? null,
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
