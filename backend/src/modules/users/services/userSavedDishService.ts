import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { DISH_DTO_SELECT, toDishDto, type DishDto } from '../../dishes/dto/dishDto';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { resolveDishByAnyId } from '../../dishes/utils/resolveDishByAnyId';
import { UserModel } from '../models/User';

export class UserSavedDishService {
  async addSavedDish(userId: string, dishId: string): Promise<void> {
    const dish = await this.findVisibleDish(dishId);
    if (!dish) {
      throw new AppError('Dish not found', 404);
    }

    await UserModel.updateOne(
      { _id: new Types.ObjectId(userId) },
      { $addToSet: { savedDishes: dish._id } }
    );
  }

  async removeSavedDish(userId: string, dishId: string): Promise<void> {
    const dish = await this.findVisibleDish(dishId);
    if (!dish) {
      throw new AppError('Dish not found', 404);
    }

    await UserModel.updateOne(
      { _id: new Types.ObjectId(userId) },
      { $pull: { savedDishes: dish._id } }
    );
  }

  async listSavedDishes(userId: string): Promise<DishDto[]> {
    const user = await UserModel.findById(userId)
      .select('savedDishes')
      .lean()
      .orFail(() => new AppError('User not found', 404));

    const dishes = await DishModel.find({ _id: { $in: user.savedDishes } })
      .select(DISH_DTO_SELECT)
      .lean();
    const visibleDishes = dishes.filter((dish) => this.isVisibleDishStatus(dish.status));

    return visibleDishes
      .map((dish) => toDishDto(dish))
      .filter((dish): dish is DishDto => Boolean(dish));
  }

  private async findVisibleDish(dishId: string): Promise<DishDocument | null> {
    const dish = await resolveDishByAnyId(dishId);
    if (!dish || !this.isVisibleDishStatus(dish.status)) {
      return null;
    }

    return dish;
  }

  private isVisibleDishStatus(status: DishDocument['status']): boolean {
    return status === 'approved' || status === 'active';
  }
}

export const userSavedDishService = new UserSavedDishService();
