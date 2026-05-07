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

    const localDish = await this.findDishByPublicOrObjectId(normalizedId);

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

    const filter: FilterQuery<DishDocument> = {
      sourceType: 'custom',
      createdBy: new Types.ObjectId(userId),
      status: 'active'
    };

    if (activeSession) {
      filter.coupleId = activeSession._id;
    }

    const dishes = await DishModel.find(filter).sort({ createdAt: -1 });

    return dishes.map((dish) => this.toDto(dish));
  }

  async deleteMyCustomDish(userId: string, dishId: string) {
    const normalizedId = dishId.trim();

    const candidate = await this.findDishByPublicOrObjectId(normalizedId);

    if (!candidate || candidate.sourceType !== 'custom' || candidate.status !== 'active') {
      throw new AppError('Dish not found', 404);
    }

    if (!candidate.createdBy || candidate.createdBy.toString() !== userId) {
      throw new AppError('You can delete only your own dishes', 403);
    }

    await DishModel.deleteOne({ _id: candidate._id });

    return { id: this.toPublicDishId(candidate), deleted: true };
  }

  private async findDishByPublicOrObjectId(dishId: string): Promise<DishDocument | null> {
    if (!dishId) {
      return null;
    }

    if (Types.ObjectId.isValid(dishId)) {
      // Try to find by _id first
      const dishByObjectId = await DishModel.findById(dishId);
      if (dishByObjectId) {
        return dishByObjectId;
      }
    }

    // Search by sourceId (public ID)
    const dishBySourceId = await DishModel.findOne({ sourceId: dishId });
    if (dishBySourceId) {
      return dishBySourceId;
    }

    return null;
  }

  private async buildVisibilityFilter(userId: string): Promise<FilterQuery<DishDocument>> {
    const activeSession = await this.getActiveSessionForUser(userId);

    const globalDishesFilter: FilterQuery<DishDocument> = {
      sourceType: { $ne: 'custom' }
    };

    if (!activeSession) {
      return {
        $or: [
          globalDishesFilter,
          {
            sourceType: 'custom',
            createdBy: new Types.ObjectId(userId),
            status: 'active'
          }
        ]
      };
    }

    return {
      $or: [
        globalDishesFilter,
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
    const rawDish = this.toRawDish(dish);

    return {
      id: this.toPublicDishId(rawDish),
      name: rawDish.name ?? '',
      description: rawDish.description ?? '',
      imageUrl: rawDish.imageUrl ?? '',
      cuisine: rawDish.cuisine ?? '',
      type: rawDish.type ?? '',
      mood: Array.isArray(rawDish.mood) ? rawDish.mood : [],
      diet: Array.isArray(rawDish.diet) ? rawDish.diet : [],
      ingredients: Array.isArray(rawDish.ingredients) ? rawDish.ingredients : [],
      cookTime: typeof rawDish.cookTime === 'number' ? rawDish.cookTime : 0,
      calories: rawDish.calories ?? '',
      effort: rawDish.effort ?? '',
      source: Array.isArray(rawDish.source) && rawDish.source.length > 0 ? rawDish.source : [rawDish.sourceType ?? 'custom'],
      servings: rawDish.servings ?? '',
      season: Array.isArray(rawDish.season) ? rawDish.season : [],
      popular: typeof rawDish.popular === 'boolean' ? rawDish.popular : false,
      steps: Array.isArray(rawDish.steps)
        ? rawDish.steps.map((step: any, index: number) => ({
            step: typeof step.step === 'number' ? step.step : index + 1,
            text: typeof step.text === 'string' ? step.text : String(step ?? '')
          }))
        : []
    };
  }

  private toRawDish(dish: any) {
    return typeof dish.toObject === 'function' ? dish.toObject({ virtuals: true }) : dish;
  }

  private toPublicDishId(dish: any) {
    const rawDish = this.toRawDish(dish);

    if (typeof rawDish.id === 'string' && rawDish.id.length > 0) {
      return rawDish.id;
    }

    if (typeof rawDish.sourceId === 'string' && rawDish.sourceId.length > 0) {
      return rawDish.sourceId;
    }

    return rawDish._id?.toString() ?? '';
  }
}
