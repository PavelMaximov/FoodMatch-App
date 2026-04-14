import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { DishModel } from '../../dishes/models/Dish';
import { MatchModel } from '../../matches/models/Match';
import { SwipeModel } from '../models/Swipe';

export class SwipeService {
  async createSwipe(userId: string, dishId: string, direction: 'like' | 'dislike') {
    if (process.env.DEBUG_SWIPE_PIPELINE === '1') {
      console.log('[debug][swipeService.createSwipe] userId=%s dishId=%s direction=%s', userId, dishId, direction);
    }

    if (!Types.ObjectId.isValid(userId)) {
      throw new AppError('Invalid token user id', 401);
    }

    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('User has no active session', 409);
    }

    const dish = await this.findDishForSwipe(dishId);
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

    const matchCreated = direction === 'like' ? await this.tryCreateMatch(session.id, dish.id) : false;
    const publicDishId = this.toPublicDishId(dish);

    return {
      id: swipe.id,
      userId,
      coupleId: session.id,
      dishId: publicDishId,
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
    return matches.map((match) => ({
      id: match.id,
      dish: match.dishId,
      users: match.users,
      createdAt: match.createdAt
    }));
  }

  async getMySwipeHistory(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) {
      throw new AppError('User has no active session', 404);
    }

    const swipes = await SwipeModel.find({ userId: new Types.ObjectId(userId), coupleId: session._id })
      .populate('dishId')
      .sort({ createdAt: -1 });

    return swipes.map((swipe) => ({
      id: swipe.id,
      direction: swipe.direction,
      createdAt: swipe.createdAt,
      dish: swipe.dishId
    }));
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

  private async findDishForSwipe(dishId: string) {
    const normalizedDishId = dishId.trim();

    if (Types.ObjectId.isValid(normalizedDishId)) {
      if (process.env.DEBUG_SWIPE_PIPELINE === '1') {
        console.log('[debug][swipeService.findDishForSwipe] lookup by _id=%s', normalizedDishId);
      }

      const dishByObjectId = await DishModel.findById(normalizedDishId);
      if (dishByObjectId) {
        return dishByObjectId;
      }
    }

    if (process.env.DEBUG_SWIPE_PIPELINE === '1') {
      console.log('[debug][swipeService.findDishForSwipe] lookup by sourceId=%s', normalizedDishId);
    }

    return DishModel.findOne({ sourceId: normalizedDishId });
  }

  private toPublicDishId(dish: { id?: string; _id?: Types.ObjectId; sourceId?: string }) {
    if (typeof dish.sourceId === 'string' && dish.sourceId.length > 0) {
      return dish.sourceId;
    }

    if (typeof dish.id === 'string' && dish.id.length > 0) {
      return dish.id;
    }

    return dish._id?.toString() ?? '';
  }
}
