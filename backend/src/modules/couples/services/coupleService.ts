import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { generateInviteCode } from '../../../core/utils/inviteCode';
import { MatchModel } from '../../matches/models/Match';
import { SwipeModel } from '../../swipes/models/Swipe';
import { CoupleSessionModel } from '../models/CoupleSession';

export class CoupleService {
  async getMyActiveSession(userId: string) {
    return CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' }).populate('members', 'email displayName');
  }

  async createSession(userId: string) {
    const active = await this.getMyActiveSession(userId);
    if (active) {
      throw new AppError('User already has an active session', 409);
    }

    const inviteCode = await this.generateUniqueInviteCode();
    const session = await CoupleSessionModel.create({
      inviteCode,
      members: [new Types.ObjectId(userId)],
      createdBy: new Types.ObjectId(userId),
      status: 'active'
    });

    return session;
  }

  async joinSession(userId: string, inviteCode: string) {
    const active = await this.getMyActiveSession(userId);
    if (active) {
      throw new AppError('User already has an active session', 409);
    }

    const session = await CoupleSessionModel.findOne({ inviteCode: inviteCode.toUpperCase(), status: 'active' });
    if (!session) {
      throw new AppError('Session not found', 404);
    }

    if (session.members.some((memberId) => memberId.toString() === userId)) {
      throw new AppError('You are already in this session', 409);
    }

    if (session.members.length >= 2) {
      throw new AppError('Session is full', 409);
    }

    session.members.push(new Types.ObjectId(userId));
    await session.save();
    return session;
  }

  async leaveSession(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('No active session found', 404);
    }

    session.members = session.members.filter((memberId) => memberId.toString() !== userId);

    if (session.members.length === 0) {
      await SwipeModel.deleteMany({ coupleId: session._id });
      await MatchModel.deleteMany({ coupleId: session._id });
      await CoupleSessionModel.deleteOne({ _id: session._id });
      return { message: 'Session deleted because no members remain' };
    }

    session.status = 'closed';
    await session.save();
    return { message: 'Session closed after member left' };
  }

  async resetSession(userId: string) {
    const session = await this.getMyActiveSession(userId);
    if (!session) {
      throw new AppError('No active session found', 404);
    }

    await SwipeModel.deleteMany({ coupleId: session._id });
    await MatchModel.deleteMany({ coupleId: session._id });

    return { message: 'Session swipes and matches reset', coupleId: session.id };
  }

  private async generateUniqueInviteCode(): Promise<string> {
    for (let i = 0; i < 10; i += 1) {
      const code = generateInviteCode();
      const exists = await CoupleSessionModel.exists({ inviteCode: code });
      if (!exists) {
        return code;
      }
    }
    throw new AppError('Failed to generate unique invite code', 500);
  }
}
