import { FilterQuery, Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { DishDocument, DishModel } from '../models/Dish';

export class DishService {
  async listDishes(query?: string) {
    if (query?.trim()) {
      return this.searchDishes(query.trim());
    }

    const dishes = await DishModel.find({}).sort({ updatedAt: -1 }).limit(20);
    return dishes.map((dish) => this.toDto(dish));
  }

  async searchDishes(query: string) {
    const normalizedQuery = query.trim();
    if (!normalizedQuery) {
      return [];
    }

    const queryRegex = new RegExp(this.escapeRegex(normalizedQuery), 'i');
    const filter: FilterQuery<DishDocument> = {
      $or: [{ name: queryRegex }, { description: queryRegex }, { cuisine: queryRegex }, { type: queryRegex }, { ingredients: queryRegex }]
    };

    const dishes = await DishModel.find(filter).sort({ updatedAt: -1 }).limit(20);
    return dishes.map((dish) => this.toDto(dish));
  }

  async getDishById(id: string) {
    const normalizedId = id.trim();

    if (Types.ObjectId.isValid(normalizedId)) {
      const localDish = await DishModel.findById(normalizedId);
      if (localDish) {
        return this.toDto(localDish);
      }
    }

    const localBySourceId = await DishModel.findOne({ sourceId: normalizedId });
    if (localBySourceId) {
      return this.toDto(localBySourceId);
    }

    throw new AppError('Dish not found', 404);
  }

  async getRandomDish() {
    const randomDish = await DishModel.aggregate([{ $sample: { size: 1 } }]);
    if (randomDish.length === 0) {
      throw new AppError('Dish not found', 404);
    }

    return this.toDto(randomDish[0]);
  }

  private escapeRegex(value: string) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  private toDto(dish: any) {
    const publicId = typeof dish.sourceId === 'string' && dish.sourceId.length > 0 ? dish.sourceId : dish.id;

    return {
      id: publicId,
      name: dish.name ?? '',
      description: dish.description ?? '',
      imageUrl: dish.imageUrl ?? '',
      cuisine: dish.cuisine ?? '',
      type: dish.type ?? '',
      mood: Array.isArray(dish.mood) ? dish.mood : [],
      diet: Array.isArray(dish.diet) ? dish.diet : [],
      ingredients: Array.isArray(dish.ingredients) ? dish.ingredients : [],
      cookTime: typeof dish.cookTime === 'number' ? dish.cookTime : 0,
      calories: dish.calories ?? '',
      effort: dish.effort ?? '',
      source: Array.isArray(dish.source) && dish.source.length > 0 ? dish.source : [dish.sourceType ?? 'custom'],
      servings: dish.servings ?? '',
      season: Array.isArray(dish.season) ? dish.season : [],
      popular: typeof dish.popular === 'boolean' ? dish.popular : false,
      steps: Array.isArray(dish.steps)
        ? dish.steps.map((step: any, index: number) => ({
            step: typeof step.step === 'number' ? step.step : index + 1,
            text: typeof step.text === 'string' ? step.text : String(step ?? '')
          }))
        : []
    };
  }
}
