import { Response } from 'express';
import { AppError } from '../../../core/errors/AppError';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { DishService } from '../services/dishService';

const dishService = new DishService();

function queryToString(value: string | string[] | undefined): string {
  if (!value) return '';
  return Array.isArray(value) ? value[0] : value;
}

export class DishController {
  async list(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dishes = await dishService.listDishes(userId, queryToString(req.query.q as string | string[] | undefined));
    res.json({ dishes });
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
      mood: String(req.body?.mood ?? ''),
      ingredients: Array.isArray(req.body?.ingredients) ? req.body.ingredients : [],
      cookTime: Number(req.body?.cookTime ?? 0),
      servings: String(req.body?.servings ?? ''),
      steps: Array.isArray(req.body?.steps) ? req.body.steps : [],
      imageUrl: req.body?.imageUrl ? String(req.body.imageUrl) : ''
    });

    res.status(201).json({ dish });
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
