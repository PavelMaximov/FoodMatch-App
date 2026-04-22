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
    session.filterState = undefined;
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
    session.filterState = undefined;
    await session.save();

    return { message: 'Session swipes and matches reset', coupleId: session.id };
  }

  async getFilterState(userId: string) {
    const session = await this.getMyActiveSession(userId);
    if (!session) {
      throw new AppError('No active session found', 404);
    }

    return this.buildFilterStateResponse(session);
  }

  async updateFilterState(
    userId: string,
    input: {
      step: number;
      cuisines: string[];
      moods: string[];
      blocked: string[];
      diet: string[];
      confirmed: boolean;
    }
  ) {
    const session = await this.getMyActiveSession(userId);
    if (!session) {
      throw new AppError('No active session found', 404);
    }

    const me = new Types.ObjectId(userId);
    const drafts = session.filterState?.drafts ?? [];
    const now = new Date();
    const foundIndex = drafts.findIndex((draft) => draft.userId.toString() === userId);
    const nextDraft = {
      userId: me,
      cuisines: input.cuisines,
      moods: input.moods,
      blocked: input.blocked,
      diet: input.diet,
      confirmed: input.confirmed,
      updatedAt: now
    };

    if (foundIndex >= 0) {
      drafts[foundIndex] = nextDraft;
    } else {
      drafts.push(nextDraft);
    }

    session.filterState = {
      step: input.step,
      drafts,
      updatedAt: now
    };

    await session.save();
    return this.buildFilterStateResponse(session);
  }

  async clearFilterState(userId: string) {
    const session = await this.getMyActiveSession(userId);
    if (!session) {
      throw new AppError('No active session found', 404);
    }
    session.filterState = undefined;
    await session.save();
    return { cleared: true };
  }

  private buildFilterStateResponse(session: any) {
    const rawState = session.filterState;
    const drafts = (rawState?.drafts ?? []).map((draft: any) => ({
      userId: draft.userId.toString(),
      cuisines: draft.cuisines ?? [],
      moods: draft.moods ?? [],
      blocked: draft.blocked ?? [],
      diet: draft.diet ?? [],
      confirmed: Boolean(draft.confirmed),
      updatedAt: draft.updatedAt ?? new Date()
    }));

    return {
      step: rawState?.step ?? 1,
      drafts,
      compatibility: this.calculateCompatibility(drafts),
      updatedAt: rawState?.updatedAt ?? session.updatedAt
    };
  }

  private calculateCompatibility(drafts: any[]) {
    if (drafts.length < 2) {
      return 0;
    }
    const [a, b] = drafts;

    const cuisine = this.overlapScore(a.cuisines, b.cuisines);
    const mood = this.overlapScore(a.moods, b.moods);
    const blocked = this.blockedScore(a.blocked, b.blocked);
    return Number((((cuisine + mood + blocked) / 3) * 100).toFixed(0));
  }

  private overlapScore(left: string[], right: string[]) {
    if (left.length === 0 && right.length === 0) {
      return 1;
    }
    if (left.length === 0 || right.length === 0) {
      return 0.4;
    }
    if (left.includes('Any') || right.includes('Any')) {
      return 0.9;
    }
    const leftSet = new Set(left);
    const rightSet = new Set(right);
    const union = new Set([...leftSet, ...rightSet]);
    const intersectionCount = [...leftSet].filter((item) => rightSet.has(item)).length;
    return union.size === 0 ? 1 : intersectionCount / union.size;
  }

  private blockedScore(left: string[], right: string[]) {
    if (left.length === 0 && right.length === 0) {
      return 1;
    }
    if (left.length === 0 || right.length === 0) {
      return 0.6;
    }
    const leftSet = new Set(left);
    const rightSet = new Set(right);
    const conflict = [...leftSet].every((item) => rightSet.has(item));
    return conflict ? 0.95 : 0.75;
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
