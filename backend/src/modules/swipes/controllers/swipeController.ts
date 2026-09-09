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
    if (process.env.NODE_ENV !== 'production') console.info(`[Matches] request user=${req.user!.id} mode=${mode} scope=${scope} sessionId=${sessionId ?? 'none'}`);
    const matches = await swipeService.getMyMatches(req.user!.id, mode, { scope, sessionId });
    if (process.env.NODE_ENV !== 'production') {
      const sessionIds = [...new Set(matches.map((match: any) => match.sessionId).filter(Boolean))];
      console.info(`[Matches] result count=${matches.length} sessionIds=${sessionIds.join(',') || 'none'}`);
      console.info(`[Matches] result dishIds=${matches.slice(0, 5).map((match: any) => match.dish?.id).filter(Boolean).join(',') || 'none'}`);
    }
    res.json({ matches });
  }

  async history(req: AuthRequest, res: Response) {
    const history = await swipeService.getMySwipeHistory(req.user!.id);
    res.json({ history });
  }
}

export const swipeController = new SwipeController();
