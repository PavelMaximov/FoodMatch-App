import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { SwipeService } from '../services/swipeService';

const swipeService = new SwipeService();

export class SwipeController {
  async create(req: AuthRequest, res: Response) {
    const { dishId, direction } = req.body;
    const swipe = await swipeService.createSwipe(req.userId!, dishId, direction);
    res.status(201).json({ swipe });
  }

  async matches(req: AuthRequest, res: Response) {
    const matches = await swipeService.getMyMatches(req.userId!);
    res.json({ matches });
  }

  async history(req: AuthRequest, res: Response) {
    const history = await swipeService.getMySwipeHistory(req.userId!);
    res.json({ history });
  }
}

export const swipeController = new SwipeController();
