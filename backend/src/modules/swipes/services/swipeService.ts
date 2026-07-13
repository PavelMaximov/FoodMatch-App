import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { DISH_DTO_SELECT, toDishDto, toPublicDishId } from '../../dishes/dto/dishDto';
import { resolveDishByAnyId } from '../../dishes/utils/resolveDishByAnyId';
import { MatchModel } from '../../matches/models/Match';
import { SwipeModel } from '../models/Swipe';
import { SoloSwipeSessionModel } from '../../solo-swipes/models/SoloSwipeSession';

export class SwipeService {
  async createSwipe(userId: string, dishId: string, direction: 'like' | 'dislike') {
    if (!Types.ObjectId.isValid(userId)) {
      throw new AppError('Invalid token user id', 401);
    }

    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('No active session', 409, 'NO_ACTIVE_SESSION');
    }

    const dish = await resolveDishByAnyId(dishId);
    if (!dish) {
      throw new AppError('This dish is not available.', 404);
    }
    if (dish.visibility === 'public' && dish.status === 'approved') {
      // Public approved dishes are swipeable.
    } else if (!(dish.isCustom && dish.visibility === 'session' && dish.status === 'approved' && dish.coupleId?.toString() === session._id.toString())) {
      throw new AppError('This dish is not available.', 404);
    }

    const swipeFilter = {
      userId: new Types.ObjectId(userId),
      coupleId: session._id,
      dishId: dish._id
    };

    const existingSwipe = await SwipeModel.findOne(swipeFilter);
    if (existingSwipe) {
      const matchId = existingSwipe.direction === 'like'
        ? await this.tryCreateMatch(session.id, dish._id.toString())
        : null;
      return this.buildSwipeResponse(existingSwipe, userId, session.id, toPublicDishId(dish), Boolean(matchId), true, matchId);
    }

    try {
      const swipe = await SwipeModel.create({ ...swipeFilter, direction });
      const matchId = direction === 'like' ? await this.tryCreateMatch(session.id, dish._id.toString()) : null;
      return this.buildSwipeResponse(swipe, userId, session.id, toPublicDishId(dish), Boolean(matchId), false, matchId);
    } catch (error) {
      if (this.isDuplicateKeyError(error)) {
        const duplicateSwipe = await SwipeModel.findOne(swipeFilter);
        if (duplicateSwipe) {
          const matchId = duplicateSwipe.direction === 'like'
            ? await this.tryCreateMatch(session.id, dish._id.toString())
            : null;
          return this.buildSwipeResponse(duplicateSwipe, userId, session.id, toPublicDishId(dish), Boolean(matchId), true, matchId);
        }

        console.warn('[Swipes] duplicate index conflict without matching swipe; run swipes index migration', error);
        throw new AppError('This dish was already swiped in this session.', 409, 'DUPLICATE_SWIPE');
      }
      throw error;
    }
  }

  async getMyMatches(
    userId: string,
    mode: 'solo' | 'paired' | 'all' = 'all',
    options: { scope?: 'current' | 'all'; sessionId?: string } = {}
  ) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (mode === 'paired' && !session) {
      throw new AppError('User has no active paired session', 404, 'NO_ACTIVE_SESSION');
    }

    const matches = session && mode !== 'solo'
      ? await MatchModel.find({ coupleId: session._id })
          .sort({ createdAt: -1 })
          .populate({ path: 'dishId', select: DISH_DTO_SELECT })
          .lean()
      : [];
    const validMatches = [];

    for (const match of matches) {
      const dish = toDishDto(match.dishId);
      if (!dish) {
        console.warn('[Matches] Skipping match with missing dish', {
          matchId: match._id?.toString() ?? '',
          dishRef: match.dishId
        });
        continue;
      }

      validMatches.push({
        id: match._id?.toString() ?? '',
        coupleId: session!._id.toString(),
        dish,
        users: match.users,
        createdAt: match.createdAt
      });
    }

    if (mode === 'paired') {
      return validMatches.map((match) => ({ ...match, mode: 'paired', matchType: 'pair_match' }));
    }

    const soloSessionQuery: Record<string, unknown> = {
      userId: new Types.ObjectId(userId),
      resultDishIds: { $ne: [] }
    };
    if (mode === 'solo' && options.sessionId && Types.ObjectId.isValid(options.sessionId)) {
      soloSessionQuery._id = new Types.ObjectId(options.sessionId);
    } else if (mode === 'solo' && options.scope === 'current') {
      soloSessionQuery.status = 'active';
    }

    const soloSessions = await SoloSwipeSessionModel.find(soloSessionQuery)
      .select('resultDishIds updatedAt')
      .sort({ updatedAt: -1 })
      .lean();
    const seenSoloDishIds = new Set<string>();
    const soloEntries = soloSessions.flatMap((session) =>
      (session.resultDishIds ?? []).map((dishId) => ({
        dishId,
        sessionId: session._id.toString(),
        createdAt: session.updatedAt
      }))
    ).filter((entry) => { const key = entry.dishId.toString(); if (seenSoloDishIds.has(key)) return false; seenSoloDishIds.add(key); return true; });
    const soloDishIds = soloEntries.map((entry) => entry.dishId);
    const soloDishes = await import('../../dishes/models/Dish').then(({ DishModel }) => DishModel.find({ _id: { $in: soloDishIds } }).select(DISH_DTO_SELECT).lean());
    const soloById = new Map(soloDishes.map((dish: any) => [dish._id.toString(), dish]));
    const soloMatches = soloEntries.map((entry) => {
      const dish = toDishDto(soloById.get(entry.dishId.toString()));
      if (!dish) return null;
      return { id: `solo_${entry.dishId.toString()}`, dish, users: [new Types.ObjectId(userId)], sessionId: entry.sessionId, createdAt: entry.createdAt ?? new Date(), mode: 'solo', matchType: 'solo_pick' };
    }).filter((match): match is NonNullable<typeof match> => Boolean(match));

    if (mode === 'solo') {
      return soloMatches;
    }

    return [...soloMatches, ...validMatches.map((match) => ({ ...match, mode: 'paired', matchType: 'pair_match' }))];
  }

  async getMySwipeHistory(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('User has no active session', 404);
    }

    const swipes = await SwipeModel.find({ userId: new Types.ObjectId(userId), coupleId: session._id })
      .select('direction createdAt dishId')
      .populate({ path: 'dishId', select: DISH_DTO_SELECT })
      .sort({ createdAt: -1 })
      .lean();

    return swipes
      .map((swipe) => {
        const dish = toDishDto(swipe.dishId);
        if (!dish) {
          return null;
        }

        return {
          id: swipe.id ?? swipe._id?.toString() ?? '',
          direction: swipe.direction,
          createdAt: swipe.createdAt,
          dish
        };
      })
      .filter((swipe): swipe is NonNullable<typeof swipe> => Boolean(swipe));
  }

  private buildSwipeResponse(
    swipe: { id?: string; _id?: Types.ObjectId; direction: 'like' | 'dislike' },
    userId: string,
    coupleId: string,
    publicDishId: string,
    matchCreated: boolean,
    alreadySwiped: boolean,
    matchId: string | null = null
  ) {
    return {
      id: swipe.id ?? swipe._id?.toString() ?? '',
      userId,
      coupleId,
      dishId: publicDishId,
      direction: swipe.direction,
      matchCreated,
      matchId,
      alreadySwiped
    };
  }

  private async tryCreateMatch(coupleId: string, dishId: string): Promise<string | null> {
    const likes = await SwipeModel.find({ coupleId: new Types.ObjectId(coupleId), dishId: new Types.ObjectId(dishId), direction: 'like' })
      .select('userId')
      .lean();
    if (likes.length < 2) {
      return null;
    }

    const uniqueUserIds = [...new Set(likes.map((like) => like.userId.toString()))];
    if (uniqueUserIds.length < 2) {
      return null;
    }

    const result = await MatchModel.updateOne(
      { coupleId: new Types.ObjectId(coupleId), dishId: new Types.ObjectId(dishId) },
      { $setOnInsert: { users: uniqueUserIds.map((id) => new Types.ObjectId(id)) } },
      { upsert: true }
    );

    if (result.upsertedId) {
      return result.upsertedId.toString();
    }

    if (result.upsertedCount > 0) {
      const match = await MatchModel.findOne({ coupleId: new Types.ObjectId(coupleId), dishId: new Types.ObjectId(dishId) }).select('_id').lean();
      return match?._id?.toString() ?? null;
    }

    return null;
  }

  private isDuplicateKeyError(error: unknown) {
    return typeof error === 'object' && error !== null && 'code' in error && (error as { code?: number }).code === 11000;
  }
}
