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

    const swipe = await SwipeModel.findOneAndUpdate(
      {
        userId: new Types.ObjectId(userId),
        coupleId: session._id,
        dishId: dish._id
      },
      {
        $set: { direction }
      },
      { upsert: true, new: true }
    );

    const matchCreated = direction === 'like' ? await this.tryCreateMatch(session.id, dish._id.toString()) : false;

    return {
      id: swipe.id,
      userId,
      coupleId: session.id,
      dishId: toPublicDishId(dish),
      direction: swipe.direction,
      matchCreated
    };
  }

  async getMyMatches(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('User has no active session', 404);
    }

    const matches = await MatchModel.find({ coupleId: session._id }).populate('dishId');
    const validMatches = [];

    for (const match of matches) {
      const dish = toDishDto(match.dishId);
      if (!dish) {
        console.warn('[Matches] Skipping match with missing dish', {
          matchId: match.id,
          dishRef: match.dishId
        });
        continue;
      }

      validMatches.push({
        id: match.id,
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
      .populate('dishId')
      .sort({ createdAt: -1 });

    return swipes
      .map((swipe) => {
        const dish = toDishDto(swipe.dishId);
        if (!dish) {
          return null;
        }

        return {
          id: swipe.id,
          direction: swipe.direction,
          createdAt: swipe.createdAt,
          dish
        };
      })
      .filter((swipe): swipe is NonNullable<typeof swipe> => Boolean(swipe));
  }

  private async tryCreateMatch(coupleId: string, dishId: string): Promise<boolean> {
    const likes = await SwipeModel.find({ coupleId: new Types.ObjectId(coupleId), dishId: new Types.ObjectId(dishId), direction: 'like' });
    if (likes.length < 2) {
      return false;
    }

    const uniqueUserIds = [...new Set(likes.map((like) => like.userId.toString()))];
    if (uniqueUserIds.length < 2) {
      return false;
    }

    await MatchModel.updateOne(
      { coupleId: new Types.ObjectId(coupleId), dishId: new Types.ObjectId(dishId) },
      { $setOnInsert: { users: uniqueUserIds.map((id) => new Types.ObjectId(id)) } },
      { upsert: true }
    );

    return true;
  }
}
