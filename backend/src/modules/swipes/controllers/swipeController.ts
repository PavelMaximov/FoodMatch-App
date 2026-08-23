import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { SwipeService } from '../services/swipeService';

const swipeService = new SwipeService();

export class SwipeController {
  async create(req: AuthRequest, res: Response) {
    if (process.env.DEBUG_SWIPE_PIPELINE === '1') {
      console.log(
        '[debug][swipeController.create] userId=%s direction=%s hasDishId=%s',
        req.userId,
        req.body?.direction,
        Boolean(req.body?.dishId)
      );
    }
    const { dishId, direction } = req.body;
    const swipe = await swipeService.createSwipe(req.user!.id, dishId, direction);
    res.status(201).json({ swipe });
  }

  async matches(req: AuthRequest, res: Response) {
    const rawMode = typeof req.query.mode === 'string' ? req.query.mode : 'all';
    const mode = rawMode === 'solo' || rawMode === 'paired' || rawMode === 'all' ? rawMode : 'all';
    const scope = req.query.scope === 'current' ? 'current' : 'all';
    const sessionId = typeof req.query.sessionId === 'string' ? req.query.sessionId : undefined;
    const matches = await swipeService.getMyMatches(req.user!.id, mode, { scope, sessionId });
    res.json({ matches });
  }

  async history(req: AuthRequest, res: Response) {
    const history = await swipeService.getMySwipeHistory(req.user!.id);
    res.json({ history });
  }
}

export const swipeController = new SwipeController();
