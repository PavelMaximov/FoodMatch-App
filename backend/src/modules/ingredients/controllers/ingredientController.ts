import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { IngredientService } from '../services/ingredientService';

const ingredientService = new IngredientService();

function queryToString(value: string | string[] | undefined): string {
  if (!value) return '';
  return Array.isArray(value) ? value[0] : value;
}

export class IngredientController {
  async search(req: AuthRequest, res: Response) {
    const q = queryToString(req.query.q as string | string[] | undefined);
    const ingredients = await ingredientService.searchIngredients(q);
    res.json({ ingredients });
  }
}

export const ingredientController = new IngredientController();
