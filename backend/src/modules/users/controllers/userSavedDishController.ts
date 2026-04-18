import { Response } from 'express';
import { AppError } from '../../../core/errors/AppError';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { userSavedDishService } from '../services/userSavedDishService';

export class UserSavedDishController {
  async list(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dishes = await userSavedDishService.listSavedDishes(userId);
    res.json({ dishes });
  }

  async save(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dishId = String(req.params.dishId ?? '');
    await userSavedDishService.addSavedDish(userId, dishId);
    res.status(201).json({ saved: true, dishId });
  }

  async unsave(req: AuthRequest, res: Response) {
    const userId = this.requireUserId(req);
    const dishId = String(req.params.dishId ?? '');
    await userSavedDishService.removeSavedDish(userId, dishId);
    res.json({ saved: false, dishId });
  }

  private requireUserId(req: AuthRequest): string {
    if (!req.userId) {
      throw new AppError('Unauthorized', 401);
    }

    return req.userId;
  }
}

export const userSavedDishController = new UserSavedDishController();
