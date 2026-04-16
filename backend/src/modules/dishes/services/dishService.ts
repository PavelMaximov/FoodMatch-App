import { FilterQuery, Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { DishDocument, DishModel } from '../models/Dish';

interface CreateCustomDishInput {
  name: string;
  cuisine: string;
  mood: string;
  ingredients: Array<{ name: string; quantity?: string; unit?: string }>;
  cookTime: number;
  servings: string;
  steps: Array<{ step: number; text: string }>;
  imageUrl?: string;
}

export class DishService {
  async listDishes(userId: string, query?: string) {
    if (query?.trim()) {
      return this.searchDishes(userId, query.trim());
    }

    const visibilityFilter = await this.buildVisibilityFilter(userId);
    const dishes = await DishModel.find(visibilityFilter).sort({ updatedAt: -1 }).limit(50);
    return dishes.map((dish) => this.toDto(dish));
  }

  async searchDishes(userId: string, query: string) {
    const normalizedQuery = query.trim();
    if (!normalizedQuery) {
      return [];
    }

    const queryRegex = new RegExp(this.escapeRegex(normalizedQuery), 'i');
    const visibilityFilter = await this.buildVisibilityFilter(userId);
    const filter: FilterQuery<DishDocument> = {
      $and: [
        visibilityFilter,
        { $or: [{ name: queryRegex }, { description: queryRegex }, { cuisine: queryRegex }, { type: queryRegex }, { ingredients: queryRegex }] }
      ]
    };

    const dishes = await DishModel.find(filter).sort({ updatedAt: -1 }).limit(50);
    return dishes.map((dish) => this.toDto(dish));
  }

  async getDishById(userId: string, id: string) {
    const normalizedId = id.trim();

    let localDish: DishDocument | null = null;
    if (Types.ObjectId.isValid(normalizedId)) {
      localDish = await DishModel.findById(normalizedId);
    }

    if (!localDish) {
      localDish = await DishModel.findOne({ sourceId: normalizedId });
    }

    if (!localDish) {
      throw new AppError('Dish not found', 404);
    }

    await this.assertCanAccessDish(userId, localDish);
    return this.toDto(localDish);
  }

  async getRandomDish(userId: string) {
    const visibilityFilter = await this.buildVisibilityFilter(userId);
    const randomDish = await DishModel.aggregate([{ $match: visibilityFilter }, { $sample: { size: 1 } }]);
    if (randomDish.length === 0) {
      throw new AppError('Dish not found', 404);
    }

    return this.toDto(randomDish[0]);
  }

  async createCustomDish(userId: string, input: CreateCustomDishInput) {
    const activeSession = await this.getActiveSessionForUser(userId);
    if (!activeSession) {
      throw new AppError('User has no active session', 409);
    }

    const sanitizedIngredients = input.ingredients
      .map((ingredient) => ({
        name: ingredient.name.trim(),
        quantity: (ingredient.quantity ?? '').trim(),
        unit: (ingredient.unit ?? '').trim()
      }))
      .filter((ingredient) => ingredient.name.length > 0);

    const dish = await DishModel.create({
      sourceType: 'custom',
      name: input.name.trim(),
      description: '',
      imageUrl: (input.imageUrl ?? '').trim(),
      cuisine: input.cuisine.trim(),
      type: '',
      mood: [input.mood.trim()],
      diet: [],
      ingredients: sanitizedIngredients.map((ingredient) => ingredient.name),
      cookTime: Number.isFinite(input.cookTime) ? Math.max(0, Math.trunc(input.cookTime)) : 0,
      calories: '',
      effort: '',
      source: ['user'],
      servings: input.servings.trim(),
      season: [],
      popular: false,
      steps: input.steps
        .map((step, index) => ({ step: typeof step.step === 'number' ? step.step : index + 1, text: step.text.trim() }))
        .filter((step) => step.text.length > 0),
      createdBy: new Types.ObjectId(userId),
      coupleId: activeSession._id,
      structuredIngredients: sanitizedIngredients,
      status: 'active',
      rawSourceData: {
        origin: 'user-created',
        sessionScoped: true
      }
    });

    return this.toDto(dish);
  }

  async listMyCustomDishes(userId: string) {
    const activeSession = await this.getActiveSessionForUser(userId);
    if (!activeSession) {
      return [];
    }

    const dishes = await DishModel.find({
      sourceType: 'custom',
      createdBy: new Types.ObjectId(userId),
      coupleId: activeSession._id,
      status: 'active'
    }).sort({ createdAt: -1 });

    return dishes.map((dish) => this.toDto(dish));
  }

  async deleteMyCustomDish(userId: string, dishId: string) {
    const normalizedId = dishId.trim();

    const dish = Types.ObjectId.isValid(normalizedId)
      ? await DishModel.findById(normalizedId)
      : await DishModel.findOne({ sourceId: normalizedId });

    if (!dish || dish.sourceType !== 'custom' || dish.status !== 'active') {
      throw new AppError('Dish not found', 404);
    }

    if (!dish.createdBy || dish.createdBy.toString() !== userId) {
      throw new AppError('You can delete only your own dishes', 403);
    }

    dish.status = 'deleted';
    await dish.save();

    return { id: dish.id, deleted: true };
  }

  private async buildVisibilityFilter(userId: string): Promise<FilterQuery<DishDocument>> {
    const activeSession = await this.getActiveSessionForUser(userId);

    if (!activeSession) {
      return { $or: [{ sourceType: 'mealdb' }, { sourceType: 'custom', createdBy: new Types.ObjectId(userId), status: 'active' }] };
    }

    return {
      $or: [
        { sourceType: 'mealdb' },
        {
          sourceType: 'custom',
          coupleId: activeSession._id,
          status: 'active'
        }
      ]
    };
  }

  private async assertCanAccessDish(userId: string, dish: DishDocument) {
    if (dish.sourceType !== 'custom') {
      return;
    }

    if (dish.status !== 'active') {
      throw new AppError('Dish not found', 404);
    }

    if (!dish.coupleId) {
      throw new AppError('Dish not found', 404);
    }

    const activeSession = await this.getActiveSessionForUser(userId);
    if (!activeSession || activeSession._id.toString() !== dish.coupleId.toString()) {
      throw new AppError('Dish not found', 404);
    }
  }

  private async getActiveSessionForUser(userId: string) {
    return CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
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
