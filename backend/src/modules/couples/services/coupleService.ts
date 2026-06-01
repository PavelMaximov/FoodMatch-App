import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { generateInviteCode } from '../../../core/utils/inviteCode';
import { MatchModel } from '../../matches/models/Match';
import { SwipeModel } from '../../swipes/models/Swipe';
import { CoupleFilterState, CoupleFilterUserChoice, CoupleSessionDocument, CoupleSessionModel } from '../models/CoupleSession';
import { clearPreparedDeck } from './coupleDeckService';

export class CoupleService {
  async getMyActiveSession(userId: string) {
    return CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' }).populate('members', 'email displayName');
  }

  async createSession(userId: string) {
    const active = await this.getMyActiveSession(userId);
    if (active) throw new AppError('User already has an active session', 409);

    const inviteCode = await this.generateUniqueInviteCode();
    return CoupleSessionModel.create({
      inviteCode,
      members: [new Types.ObjectId(userId)],
      createdBy: new Types.ObjectId(userId),
      status: 'active',
      filterState: { users: [], status: 'draft', updatedAt: null }
    });
  }

  async joinSession(userId: string, inviteCode: string) {
    const active = await this.getMyActiveSession(userId);
    if (active) throw new AppError('User already has an active session', 409);

    const session = await CoupleSessionModel.findOne({ inviteCode: inviteCode.toUpperCase(), status: 'active' });
    if (!session) throw new AppError('Session not found', 404);
    if (session.members.some((memberId) => memberId.toString() === userId)) throw new AppError('You are already in this session', 409);
    if (session.members.length >= 2) throw new AppError('Session is full', 409);

    session.members.push(new Types.ObjectId(userId));
    this.ensureFilterState(session);
    clearPreparedDeck(session);
    await session.save();
    return session;
  }

  async leaveSession(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) throw new AppError('No active session found', 404);

    session.members = session.members.filter((memberId) => memberId.toString() !== userId);
    if (session.filterState?.users) {
      session.filterState.users = session.filterState.users.filter((entry) => entry.userId.toString() !== userId);
      session.filterState.status = 'draft';
      session.filterState.updatedAt = new Date();
    }
    clearPreparedDeck(session);

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
    if (!session) throw new AppError('No active session found', 404);

    await SwipeModel.deleteMany({ coupleId: session._id });
    await MatchModel.deleteMany({ coupleId: session._id });
    this.clearFilterState(session as CoupleSessionDocument);
    clearPreparedDeck(session as CoupleSessionDocument);
    await (session as CoupleSessionDocument).save();

    return { message: 'Session swipes and matches reset', coupleId: session.id };
  }

  async getFilterState(userId: string) {
    const session = await this.requireActiveSession(userId);
    const response = this.buildFilterStateResponse(session, userId);
    console.log(`[CoupleFilterState] get user=${userId} couple=${session.id}`);
    console.log(`[CoupleFilterState] compatibility=${response.compatibility}`);
    return response;
  }

  async updateMyFilterState(userId: string, payload: { cuisines?: string[]; moods?: string[]; diet?: string[]; exclusions?: string[] }) {
    const session = await this.requireActiveSession(userId);
    const now = new Date();
    const entry = this.upsertUserFilterEntry(session, userId);

    entry.cuisines = this.normalizeList(payload.cuisines);
    entry.moods = this.normalizeList(payload.moods);
    entry.diet = this.normalizeList(payload.diet);
    entry.exclusions = this.normalizeList(payload.exclusions);
    entry.confirmed = false;
    entry.updatedAt = now;

    session.filterState!.status = 'draft';
    session.filterState!.updatedAt = now;
    clearPreparedDeck(session);

    await session.save();
    console.log(`[CoupleFilterState] update user=${userId} choices=c${entry.cuisines.length}/m${entry.moods.length}/d${entry.diet.length}/e${entry.exclusions.length}`);
    return this.buildFilterStateResponse(session, userId);
  }

  async confirmMyFilterState(userId: string) {
    const session = await this.requireActiveSession(userId);
    const now = new Date();
    const entry = this.upsertUserFilterEntry(session, userId);
    entry.confirmed = true;
    entry.updatedAt = now;

    const hasPartner = session.members.some((memberId) => memberId.toString() !== userId);
    const partnerConfirmed = session.filterState!.users.some((u) => u.userId.toString() !== userId && u.confirmed);
    const bothConfirmed = hasPartner && entry.confirmed && partnerConfirmed;
    session.filterState!.status = bothConfirmed ? 'ready' : 'draft';
    session.filterState!.updatedAt = now;
    await session.save();

    console.log(`[CoupleFilterState] confirm user=${userId} bothConfirmed=${bothConfirmed}`);
    return this.buildFilterStateResponse(session, userId);
  }

  async resetFilterState(userId: string) {
    const session = await this.requireActiveSession(userId);
    this.clearFilterState(session);
    clearPreparedDeck(session);
    await session.save();
    console.log(`[CoupleFilterState] reset couple=${session.id}`);
    return this.buildFilterStateResponse(session, userId);
  }

  private async requireActiveSession(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) throw new AppError('No active session found', 404);
    this.ensureFilterState(session);
    return session;
  }

  private ensureFilterState(session: CoupleSessionDocument) {
    if (!session.filterState) session.filterState = { users: [], status: 'draft', updatedAt: null };
    if (!Array.isArray(session.filterState.users)) session.filterState.users = [];
    if (!session.filterState.status) session.filterState.status = 'draft';
    if (typeof session.filterState.updatedAt === 'undefined') session.filterState.updatedAt = null;
  }

  private clearFilterState(session: CoupleSessionDocument) {
    this.ensureFilterState(session);
    session.filterState = { users: [], status: 'draft', updatedAt: new Date() };
  }

  private upsertUserFilterEntry(session: CoupleSessionDocument, userId: string): CoupleFilterUserChoice {
    this.ensureFilterState(session);
    session.filterState!.users = session.filterState!.users.filter((entry, index, arr) => arr.findIndex((e) => e.userId.toString() === entry.userId.toString()) === index);
    let entry = session.filterState!.users.find((u) => u.userId.toString() === userId);
    if (!entry) {
      entry = { userId: new Types.ObjectId(userId), cuisines: [], moods: [], diet: [], exclusions: [], confirmed: false, updatedAt: null };
      session.filterState!.users.push(entry);
    }
    return entry;
  }

  private normalizeList(values?: string[]) {
    if (!Array.isArray(values)) return [];
    const normalized = values.map((v) => (v ?? '').trim().toLowerCase()).filter((v) => v.length > 0);
    return [...new Set(normalized)];
  }

  private calculateCompatibility(mine: CoupleFilterUserChoice, partner?: CoupleFilterUserChoice | null) {
    if (!partner) return 0;
    const overlapPoints = (a: string[], b: string[], maxPoints: number) => {
      if (a.length === 0 || b.length === 0) return 0;
      const inter = a.filter((x) => b.includes(x)).length;
      const denom = Math.max(a.length, b.length);
      return Math.round((inter / denom) * maxPoints);
    };

    let score = 0;
    score += overlapPoints(mine.cuisines, partner.cuisines, 40);
    score += overlapPoints(mine.moods, partner.moods, 30);

    const hasDiet = mine.diet.length > 0 || partner.diet.length > 0;
    if (!hasDiet) score += 20;
    else if (mine.diet.some((d) => partner.diet.includes(d))) score += 20;
    else score += 10;

    const exclusionConflicts = mine.exclusions.filter((e) => partner.cuisines.includes(e)).length + partner.exclusions.filter((e) => mine.cuisines.includes(e)).length;
    score -= Math.min(10, exclusionConflicts * 5);

    return Math.max(0, Math.min(100, score));
  }

  private buildFilterStateResponse(session: CoupleSessionDocument, userId: string) {
    this.ensureFilterState(session);
    const myEntry = this.upsertUserFilterEntry(session, userId);
    const partnerEntry = session.filterState!.users.find((u) => u.userId.toString() !== userId) ?? null;
    const bothConfirmed = Boolean(partnerEntry && myEntry.confirmed && partnerEntry.confirmed);
    if (bothConfirmed && session.filterState!.status !== 'ready') session.filterState!.status = 'ready';

    return {
      myChoices: { cuisines: myEntry.cuisines, moods: myEntry.moods, diet: myEntry.diet, exclusions: myEntry.exclusions, confirmed: myEntry.confirmed, updatedAt: myEntry.updatedAt },
      partnerChoices: partnerEntry
        ? { cuisines: partnerEntry.cuisines, moods: partnerEntry.moods, diet: partnerEntry.diet, exclusions: partnerEntry.exclusions, confirmed: partnerEntry.confirmed, updatedAt: partnerEntry.updatedAt }
        : null,
      bothConfirmed,
      compatibility: this.calculateCompatibility(myEntry, partnerEntry),
      status: bothConfirmed ? 'ready' : session.filterState!.status || 'draft'
    };
  }

  private async generateUniqueInviteCode(): Promise<string> { for (let i = 0; i < 10; i += 1) { const code = generateInviteCode(); const exists = await CoupleSessionModel.exists({ inviteCode: code }); if (!exists) return code; } throw new AppError('Failed to generate unique invite code', 500); }
}
