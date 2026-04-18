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
    this.validateObjectId(dishId);

    const dish = await DishModel.findOne({ _id: new Types.ObjectId(dishId), status: 'active' });
    if (!dish) {
      throw new AppError('Dish not found', 404);
    }

    await UserModel.updateOne(
      { _id: new Types.ObjectId(userId) },
      { $addToSet: { savedDishes: new Types.ObjectId(dishId) } }
    );
  }

  async removeSavedDish(userId: string, dishId: string): Promise<void> {
    this.validateObjectId(dishId);

    await UserModel.updateOne(
      { _id: new Types.ObjectId(userId) },
      { $pull: { savedDishes: new Types.ObjectId(dishId) } }
    );
  }

  private validateObjectId(id: string): void {
    if (!Types.ObjectId.isValid(id)) {
      throw new AppError('Invalid dish id', 400);
    }
  }
}

export const userSavedDishService = new UserSavedDishService();
