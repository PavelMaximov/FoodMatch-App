import { Response } from 'express';
import { AppError } from '../../../core/errors/AppError';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { DishListOptions, DishService } from '../services/dishService';

const dishService = new DishService();

function queryToString(value: string | string[] | undefined): string {
  if (!value) return '';
  return Array.isArray(value) ? value[0] : value;
}

function queryToValues(value: string | string[] | undefined): string[] {
  if (!value) return [];
  const rawValues = Array.isArray(value) ? value : [value];
  return rawValues
    .flatMap((rawValue) => String(rawValue).split(','))
    .map((rawValue) => rawValue.trim().toLowerCase())
    .filter(Boolean);
}

function queryToOptionalNumber(value: string | string[] | undefined): number | undefined {
  const rawValue = queryToString(value);
  if (!rawValue.trim()) return undefined;
  const parsed = Number(rawValue);
  if (!Number.isFinite(parsed)) return undefined;
  return Math.max(0, Math.trunc(parsed));
}

function queryToBoolean(value: string | string[] | undefined): boolean | undefined {
  const normalized = queryToString(value).trim().toLowerCase();
  if (['true', '1', 'yes'].includes(normalized)) return true;
  if (['false', '0', 'no'].includes(normalized)) return false;
  return undefined;
}

function parsePageOptions(query: AuthRequest['query']): DishListOptions {
  const limitRaw = Number(queryToString(query.limit as string | string[] | undefined));
  const limit = Number.isFinite(limitRaw) ? Math.min(50, Math.max(1, Math.trunc(limitRaw))) : 20;
  const offsetRaw = Number(queryToString(query.offset as string | string[] | undefined));
  const pageRaw = Number(queryToString(query.page as string | string[] | undefined));
  const offset = Number.isFinite(offsetRaw)
    ? Math.max(0, Math.trunc(offsetRaw))
    : Number.isFinite(pageRaw)
      ? Math.max(0, (Math.max(1, Math.trunc(pageRaw)) - 1) * limit)
      : 0;

  return {
    limit,
    offset,
    search: queryToString((query.search ?? query.q) as string | string[] | undefined).trim() || undefined,
    cuisine: queryToValues(query.cuisine as string | string[] | undefined),
    type: queryToValues(query.type as string | string[] | undefined),
    mood: queryToValues(query.mood as string | string[] | undefined),
    diet: queryToValues(query.diet as string | string[] | undefined),
    effort: queryToString(query.effort as string | string[] | undefined).trim().toLowerCase() || undefined,
    popular: queryToBoolean(query.popular as string | string[] | undefined),
    source: queryToString(query.source as string | string[] | undefined).trim().toLowerCase() || undefined,
    season: queryToValues(query.season as string | string[] | undefined),
    mealType: queryToValues(query.mealType as string | string[] | undefined),
    maxCookTime: queryToOptionalNumber(query.maxCookTime as string | string[] | undefined),
    maxTotalTime: queryToOptionalNumber(query.maxTotalTime as string | string[] | undefined),
    timeTier: queryToValues(query.timeTier as string | string[] | undefined),
    maxIngredients: queryToOptionalNumber(query.maxIngredients as string | string[] | undefined),
    minCalories: queryToOptionalNumber(query.minCalories as string | string[] | undefined),
    maxCalories: queryToOptionalNumber(query.maxCalories as string | string[] | undefined),
    sort: queryToString(query.sort as string | string[] | undefined).trim() || 'default'
  };
}

export class DishController {
  async list(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const limit = queryToString(req.query.limit as string | string[] | undefined).trim().toLowerCase();

    // Backward-compatible full catalog response used by pre-swipe, catalog cache, and deck fallback flows.
    // Examples for paginated clients:
    // GET /api/dishes?limit=20&offset=0
    // GET /api/dishes?search=pizza&limit=20
    // GET /api/dishes?mealType=breakfast&sort=popular&limit=20
    // GET /api/dishes?cuisine=italian,mexican&diet=vegetarian&limit=20
    if (limit === 'all') {
      const startedAt = Date.now();
      const dishes = await dishService.listDishes(
        userId,
        queryToString((req.query.search ?? req.query.q) as string | string[] | undefined),
        true
      );
      console.info(`[API] GET /api/dishes?limit=all total ms=${Date.now() - startedAt}`);
      res.json({ dishes });
      return;
    }

    const result = await dishService.listDishesPage(userId, parsePageOptions(req.query));
    res.json(result);
  }

  async getById(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dish = await dishService.getDishById(userId, queryToString(req.params.id as string | string[] | undefined));
    res.json({ dish });
  }

  async random(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dish = await dishService.getRandomDish(userId);
    res.json({ dish });
  }

  async search(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dishes = await dishService.searchDishes(userId, queryToString(req.query.q as string | string[] | undefined));
    res.json({ dishes });
  }

  async createCustom(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dish = await dishService.createCustomDish(userId, {
      name: String(req.body?.name ?? ''),
      cuisine: String(req.body?.cuisine ?? ''),
      mood: req.body?.mood ?? '',
      dishRegister: String(req.body?.dishRegister ?? ''),
      type: String(req.body?.type ?? ''),
      description: String(req.body?.description ?? ''),
      diet: Array.isArray(req.body?.diet) ? req.body.diet : [],
      source: Array.isArray(req.body?.source) ? req.body.source : [],
      season: Array.isArray(req.body?.season) ? req.body.season : [],
      ingredients: Array.isArray(req.body?.ingredients) ? req.body.ingredients : [],
      cookTime: Number(req.body?.cookTime ?? 0),
      servings: String(req.body?.servings ?? ''),
      steps: Array.isArray(req.body?.steps) ? req.body.steps : [],
      imageUrl: req.body?.imageUrl ? String(req.body.imageUrl) : '',
      imagePublicId: req.body?.imagePublicId ? String(req.body.imagePublicId) : undefined
    });

    res.status(201).json({ dish });
  }

  async updateMine(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dish = await dishService.updateMyCustomDish(userId, queryToString(req.params.id as string | string[] | undefined), {
      name: String(req.body?.name ?? ''),
      cuisine: String(req.body?.cuisine ?? ''),
      mood: req.body?.mood ?? '',
      dishRegister: String(req.body?.dishRegister ?? ''),
      type: String(req.body?.type ?? ''),
      description: String(req.body?.description ?? ''),
      diet: Array.isArray(req.body?.diet) ? req.body.diet : [],
      source: Array.isArray(req.body?.source) ? req.body.source : [],
      season: Array.isArray(req.body?.season) ? req.body.season : [],
      ingredients: Array.isArray(req.body?.ingredients) ? req.body.ingredients : [],
      cookTime: Number(req.body?.cookTime ?? 0),
      servings: String(req.body?.servings ?? ''),
      steps: Array.isArray(req.body?.steps) ? req.body.steps : [],
      imageUrl: req.body?.imageUrl ? String(req.body.imageUrl) : '',
      imagePublicId: req.body?.imagePublicId ? String(req.body.imagePublicId) : undefined
    });
    res.json({ dish });
  }

  async listMine(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dishes = await dishService.listMyCustomDishes(userId);
    res.json({ dishes });
  }

  async deleteMine(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const result = await dishService.deleteMyCustomDish(userId, queryToString(req.params.id as string | string[] | undefined));
    res.json(result);
  }

  private requireUserId(req: AuthRequest): string {
    if (!req.userId) {
      throw new AppError('Unauthorized', 401);
    }

    return req.userId;
  }
}

export const dishController = new DishController();
