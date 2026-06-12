import { FilterQuery, Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { DISH_DTO_SELECT, toDishDto, toPublicDishId } from '../dto/dishDto';
import { resolveDishByAnyId } from '../utils/resolveDishByAnyId';
import { DishDocument, DishModel } from '../models/Dish';
import { CLOUDINARY_FOLDERS, deleteImage } from '../../uploads/services/cloudinaryService';


export interface DishListFilters {
  search?: string;
  cuisine?: string[];
  type?: string[];
  mood?: string[];
  diet?: string[];
  effort?: string;
  popular?: boolean;
  source?: string;
  season?: string[];
  maxCookTime?: number;
  minCalories?: number;
  maxCalories?: number;
}

export interface DishListOptions extends DishListFilters {
  limit: number;
  offset: number;
  sort?: string;
}

export interface PaginatedDishResult {
  items: NonNullable<ReturnType<typeof toDishDto>>[];
  total: number;
  limit: number;
  offset: number;
  hasMore: boolean;
}

interface CreateCustomDishInput {
  name: string;
  cuisine: string;
  mood: string;
  ingredients: Array<{ name: string; quantity?: string; unit?: string }>;
  cookTime: number;
  servings: string;
  steps: Array<{ step: number; text: string }>;
  imageUrl?: string;
  imagePublicId?: string;
}

export class DishService {
  async listDishes(userId: string, query?: string, returnAll = false) {
    const filters: DishListFilters = { search: query?.trim() || undefined };
    const filter = await this.buildDishListFilter(userId, filters);
    const dishQuery = DishModel.find(filter).select(DISH_DTO_SELECT).sort({ updatedAt: -1 }).lean();

    if (!returnAll) {
      dishQuery.limit(50);
    }

    const dishes = await dishQuery;
    console.log(
      `[Dishes] listDishes limit=${returnAll ? 'all' : '50'} returned ${dishes.length} dishes`
    );
    return this.mapDishDtos(dishes);
  }

  async listDishesPage(userId: string, options: DishListOptions): Promise<PaginatedDishResult> {
    const filter = await this.buildDishListFilter(userId, options);
    const [total, dishes] = await Promise.all([
      DishModel.countDocuments(filter),
      DishModel.find(filter)
        .select(DISH_DTO_SELECT)
        .sort(this.sortFor(options.sort))
        .skip(options.offset)
        .limit(options.limit)
        .lean()
    ]);
    const items = this.mapDishDtos(dishes);

    return {
      items,
      total,
      limit: options.limit,
      offset: options.offset,
      hasMore: options.offset + items.length < total
    };
  }

  async searchDishes(userId: string, query: string) {
    const normalizedQuery = query.trim();
    if (!normalizedQuery) {
      return [];
    }

    const filter = await this.buildDishListFilter(userId, { search: normalizedQuery });
    const dishes = await DishModel.find(filter).select(DISH_DTO_SELECT).sort({ updatedAt: -1 }).limit(50).lean();
    return this.mapDishDtos(dishes);
  }

  async getDishById(userId: string, id: string) {
    const normalizedId = id.trim();

    const localDish = await resolveDishByAnyId(normalizedId);

    if (!localDish) {
      throw new AppError('Dish not found', 404);
    }

    await this.assertCanAccessDish(userId, localDish);
    return toDishDto(localDish);
  }

  async getRandomDish(userId: string) {
    const visibilityFilter = await this.buildVisibilityFilter(userId);
    const randomDish = await DishModel.aggregate([{ $match: visibilityFilter }, { $sample: { size: 1 } }]);
    if (randomDish.length === 0) {
      throw new AppError('Dish not found', 404);
    }

    return toDishDto(randomDish[0]);
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
      imagePublicId: this.safeCustomDishPublicId(input.imagePublicId),
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

    return toDishDto(dish);
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

    const dishes = await DishModel.find(filter).select(DISH_DTO_SELECT).sort({ createdAt: -1 }).lean();

    return dishes.map((dish) => toDishDto(dish)).filter((dish): dish is NonNullable<ReturnType<typeof toDishDto>> => Boolean(dish));
  }

  async deleteMyCustomDish(userId: string, dishId: string) {
    const normalizedId = dishId.trim();

    const candidate = await resolveDishByAnyId(normalizedId);

    if (!candidate || candidate.sourceType !== 'custom' || candidate.status !== 'active') {
      throw new AppError('Dish not found', 404);
    }

    if (!candidate.createdBy || candidate.createdBy.toString() !== userId) {
      throw new AppError('You can delete only your own dishes', 403);
    }

    if (this.isCustomDishPublicId(candidate.imagePublicId)) {
      try {
        await deleteImage(candidate.imagePublicId);
      } catch (error) {
        console.warn('[Dishes] Failed to delete custom dish Cloudinary image', {
          dishId: candidate.id,
          imagePublicId: candidate.imagePublicId,
          error
        });
      }
    }

    await DishModel.deleteOne({ _id: candidate._id });

    return { id: toPublicDishId(candidate), deleted: true };
  }


  private safeCustomDishPublicId(publicId?: string): string | undefined {
    const normalizedPublicId = publicId?.trim();
    if (!normalizedPublicId) {
      return undefined;
    }

    return this.isCustomDishPublicId(normalizedPublicId) ? normalizedPublicId : undefined;
  }

  private isCustomDishPublicId(publicId?: string): publicId is string {
    return Boolean(publicId?.startsWith(`${CLOUDINARY_FOLDERS.customDishes}/`));
  }

  private async buildDishListFilter(userId: string, filters: DishListFilters): Promise<FilterQuery<DishDocument>> {
    const visibilityFilter = await this.buildVisibilityFilter(userId);
    const clauses: FilterQuery<DishDocument>[] = [visibilityFilter];

    const search = filters.search?.trim();
    if (search) {
      const queryRegex = new RegExp(this.escapeRegex(search), 'i');
      clauses.push({
        $or: [
          { name: queryRegex },
          { description: queryRegex },
          { cuisine: queryRegex },
          { type: queryRegex },
          { ingredients: queryRegex }
        ]
      });
    }

    this.addStringInFilter(clauses, 'cuisine', filters.cuisine);
    this.addStringInFilter(clauses, 'type', filters.type);
    this.addStringInFilter(clauses, 'mood', filters.mood);
    this.addStringInFilter(clauses, 'diet', filters.diet);
    this.addStringInFilter(clauses, 'season', filters.season);

    if (filters.effort?.trim()) {
      clauses.push({ effort: this.exactNormalizedRegex(filters.effort) });
    }

    if (typeof filters.popular === 'boolean') {
      clauses.push({ popular: filters.popular });
    }

    if (filters.source?.trim()) {
      clauses.push({ source: this.containsNormalizedRegex(filters.source) });
    }

    if (typeof filters.maxCookTime === 'number') {
      clauses.push({ cookTime: { $lte: filters.maxCookTime } });
    }

    const calorieClauses: FilterQuery<DishDocument>[] = [];
    if (typeof filters.minCalories === 'number') {
      calorieClauses.push({ 'nutrition.calories': { $gte: filters.minCalories } });
    }
    if (typeof filters.maxCalories === 'number') {
      calorieClauses.push({ 'nutrition.calories': { $lte: filters.maxCalories } });
    }
    clauses.push(...calorieClauses);

    return clauses.length === 1 ? visibilityFilter : { $and: clauses };
  }

  private addStringInFilter(clauses: FilterQuery<DishDocument>[], field: string, values?: string[]) {
    const normalizedValues = (values ?? []).map((value) => value.trim()).filter(Boolean);
    if (normalizedValues.length === 0) {
      return;
    }

    clauses.push({ [field]: { $in: normalizedValues.map((value) => this.exactNormalizedRegex(value)) } });
  }

  private sortFor(sort?: string): Record<string, 1 | -1> {
    switch ((sort ?? 'default').trim().toLowerCase()) {
      case 'popular':
        return { popular: -1, quality_score: -1, qualityScore: -1, name: 1, _id: 1 };
      case 'newest':
        return { createdAt: -1, _id: -1 };
      case 'name':
        return { name: 1, _id: 1 };
      case 'cooktime':
        return { cookTime: 1, total_time_minutes: 1, name: 1, _id: 1 };
      case 'quality':
        return { quality_score: -1, qualityScore: -1, name: 1, _id: 1 };
      default:
        return { popular: -1, quality_score: -1, qualityScore: -1, name: 1, _id: 1 };
    }
  }

  private mapDishDtos(dishes: any[]) {
    return dishes.map((dish) => toDishDto(dish)).filter((dish): dish is NonNullable<ReturnType<typeof toDishDto>> => Boolean(dish));
  }

  private exactNormalizedRegex(value: string) {
    return new RegExp(`^${this.escapeRegex(value.trim())}$`, 'i');
  }

  private containsNormalizedRegex(value: string) {
    return new RegExp(this.escapeRegex(value.trim()), 'i');
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

}