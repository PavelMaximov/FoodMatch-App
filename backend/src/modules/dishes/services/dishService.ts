import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { adaptMealDbMeal } from '../adapters/mealDbAdapter';
import { mealDbClient } from '../clients/mealDbClient';
import { DishModel } from '../models/Dish';

export class DishService {
  async listDishes(query?: string) {
    if (query?.trim()) {
      return this.searchDishes(query.trim());
    }

    const cached = await DishModel.find({ sourceType: 'mealdb' }).sort({ updatedAt: -1 }).limit(20);
    if (cached.length > 0) {
      return cached.map((dish) => this.toDto(dish));
    }

    const meals = await mealDbClient.searchByName('chicken');
    const dishes = await Promise.all(meals.slice(0, 20).map((meal) => this.upsertMealDbDish(meal)));
    return dishes.map((dish) => this.toDto(dish));
  }

  async searchDishes(query: string) {
    const meals = await mealDbClient.searchByName(query);
    const dishes = await Promise.all(meals.map((meal) => this.upsertMealDbDish(meal)));
    return dishes.map((dish) => this.toDto(dish));
  }

  async getDishById(id: string) {
    if (Types.ObjectId.isValid(id)) {
      const localDish = await DishModel.findById(id);
      if (localDish) {
        return this.toDto(localDish);
      }
    }

    const localBySourceId = await DishModel.findOne({ sourceId: id });
    if (localBySourceId) {
      return this.toDto(localBySourceId);
    }

    const meal = await mealDbClient.getById(id);
    if (!meal) {
      throw new AppError('Dish not found', 404);
    }

    const dish = await this.upsertMealDbDish(meal);
    return this.toDto(dish);
  }

  async getRandomDish() {
    const meal = await mealDbClient.getRandom();
    if (!meal) {
      throw new AppError('Unable to fetch random dish', 502);
    }

    const dish = await this.upsertMealDbDish(meal);
    return this.toDto(dish);
  }

  private async upsertMealDbDish(meal: Record<string, string | null>) {
    const normalized = adaptMealDbMeal(meal);

    return DishModel.findOneAndUpdate(
      { sourceType: 'mealdb', sourceId: normalized.sourceId },
      {
        $set: {
          ...normalized,
          createdBy: null
        }
      },
      { upsert: true, new: true }
    );
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
      source: Array.isArray(dish.source) && dish.source.length > 0 ? dish.source : [dish.sourceType ?? 'mealdb'],
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
