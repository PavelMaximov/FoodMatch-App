import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { toDishDto, toPublicDishId } from '../../dishes/dto/dishDto';
import { resolveDishByAnyId } from '../../dishes/utils/resolveDishByAnyId';
import { MatchModel } from '../../matches/models/Match';
import { SwipeModel } from '../models/Swipe';

export class SwipeService {
  async createSwipe(userId: string, dishId: string, direction: 'like' | 'dislike') {
    if (!Types.ObjectId.isValid(userId)) {
      throw new AppError('Invalid token user id', 401);
    }

    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('User has no active session', 409);
    }

    const dish = await resolveDishByAnyId(dishId);
    if (!dish) {
      throw new AppError('Dish not found', 404);
    }

    const swipeFilter = {
      userId: new Types.ObjectId(userId),
      coupleId: session._id,
      dishId: dish._id
    };

    const existingSwipe = await SwipeModel.findOne(swipeFilter);
    if (existingSwipe) {
      const matchCreated = existingSwipe.direction === 'like'
        ? await this.tryCreateMatch(session.id, dish._id.toString())
        : false;
      return this.buildSwipeResponse(existingSwipe, userId, session.id, toPublicDishId(dish), matchCreated, true);
    }

    try {
      const swipe = await SwipeModel.create({ ...swipeFilter, direction });
      const matchCreated = direction === 'like' ? await this.tryCreateMatch(session.id, dish._id.toString()) : false;
      return this.buildSwipeResponse(swipe, userId, session.id, toPublicDishId(dish), matchCreated, false);
    } catch (error) {
      if (this.isDuplicateKeyError(error)) {
        const duplicateSwipe = await SwipeModel.findOne(swipeFilter);
        if (duplicateSwipe) {
          const matchCreated = duplicateSwipe.direction === 'like'
            ? await this.tryCreateMatch(session.id, dish._id.toString())
            : false;
          return this.buildSwipeResponse(duplicateSwipe, userId, session.id, toPublicDishId(dish), matchCreated, true);
        }

        throw new AppError('Duplicate swipe index conflict. Run swipes index migration.', 409);
      }
      throw error;
    }
  }

  async getMyMatches(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('User has no active session', 404);
    }

    const matches = await MatchModel.find({ coupleId: session._id })
      .sort({ createdAt: -1 })
      .populate({ path: 'dishId', select: 'sourceId name description imageUrl imagePublicId cuisine type mood diet ingredients cookTime calories nutrition effort source servings season popular steps rawSourceData status' })
      .lean();
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
        dish,
        users: match.users,
        createdAt: match.createdAt
      });
    }

    return validMatches;
  }

  async getMySwipeHistory(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('User has no active session', 404);
    }

    const swipes = await SwipeModel.find({ userId: new Types.ObjectId(userId), coupleId: session._id })
      .select('direction createdAt dishId')
      .populate({ path: 'dishId', select: 'sourceId name description imageUrl imagePublicId cuisine type mood diet ingredients cookTime calories nutrition effort source servings season popular steps rawSourceData status' })
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
    alreadySwiped: boolean
  ) {
    return {
      id: swipe.id ?? swipe._id?.toString() ?? '',
      userId,
      coupleId,
      dishId: publicDishId,
      direction: swipe.direction,
      matchCreated,
      alreadySwiped
    };
  }

  private async tryCreateMatch(coupleId: string, dishId: string): Promise<boolean> {
    const likes = await SwipeModel.find({ coupleId: new Types.ObjectId(coupleId), dishId: new Types.ObjectId(dishId), direction: 'like' })
      .select('userId')
      .lean();
    if (likes.length < 2) {
      return false;
    }

    const uniqueUserIds = [...new Set(likes.map((like) => like.userId.toString()))];
    if (uniqueUserIds.length < 2) {
      return false;
    }

    const result = await MatchModel.updateOne(
      { coupleId: new Types.ObjectId(coupleId), dishId: new Types.ObjectId(dishId) },
      { $setOnInsert: { users: uniqueUserIds.map((id) => new Types.ObjectId(id)) } },
      { upsert: true }
    );

    return result.upsertedCount > 0;
  }

  private isDuplicateKeyError(error: unknown) {
    return typeof error === 'object' && error !== null && 'code' in error && (error as { code?: number }).code === 11000;
  }
}
