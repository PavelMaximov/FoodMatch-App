import { Request, Response } from 'express';
import { DishService } from '../services/dishService';

const dishService = new DishService();

function queryToString(value: string | string[] | undefined): string {
  if (!value) return '';
  return Array.isArray(value) ? value[0] : value;
}

export class DishController {
  async list(req: Request, res: Response) {
    const dishes = await dishService.listDishes(queryToString(req.query.q as string | string[] | undefined));
    res.json({ dishes });
  }

  async getById(req: Request, res: Response) {
    const dish = await dishService.getDishById(queryToString(req.params.id as string | string[] | undefined));
    res.json({ dish });
  }

  async random(_req: Request, res: Response) {
    const dish = await dishService.getRandomDish();
    res.json({ dish });
  }

  async search(req: Request, res: Response) {
    const dishes = await dishService.searchDishes(queryToString(req.query.q as string | string[] | undefined));
    res.json({ dishes });
  }
}

export const dishController = new DishController();
