import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { UserModel } from '../models/User';

export class UserSavedDishService {
  async listSavedDishes(userId: string): Promise<DishDocument[]> {
    const user = await UserModel.findById(userId)
      .populate({
        path: 'savedDishes',
        match: { status: 'active' }
      })
      .orFail(() => new AppError('User not found', 404));

    return (user.savedDishes as unknown as DishDocument[]) ?? [];
  }

  async addSavedDish(userId: string, dishId: string): Promise<void> {
    const dish = await this.findActiveDishByPublicOrObjectId(dishId);
    if (!dish) {
      throw new AppError('Dish not found', 404);
    }

    await UserModel.updateOne(
      { _id: new Types.ObjectId(userId) },
      { $addToSet: { savedDishes: dish._id } }
    );
  }

  async removeSavedDish(userId: string, dishId: string): Promise<void> {
    const dish = await this.findActiveDishByPublicOrObjectId(dishId);
    if (!dish) {
      throw new AppError('Dish not found', 404);
    }

    await UserModel.updateOne(
      { _id: new Types.ObjectId(userId) },
      { $pull: { savedDishes: dish._id } }
    );
  }

  private async findActiveDishByPublicOrObjectId(dishId: string): Promise<DishDocument | null> {
    const normalizedDishId = dishId.trim();
    if (!normalizedDishId) {
      return null;
    }

    if (Types.ObjectId.isValid(normalizedDishId)) {
      const dishByObjectId = await DishModel.findOne({
        _id: new Types.ObjectId(normalizedDishId),
        status: 'active'
      });
      if (dishByObjectId) {
        return dishByObjectId;
      }
    }

    return DishModel.findOne({ sourceId: normalizedDishId, status: 'active' });
  }
}

export const userSavedDishService = new UserSavedDishService();
