import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { SoloSwipeService } from '../services/soloSwipeService';
const service = new SoloSwipeService();
export class SoloSwipeController {
  async active(req: AuthRequest, res: Response) { res.json({ session: await service.getActive(req.userId!) }); }
  async create(req: AuthRequest, res: Response) { res.status(201).json({ session: await service.createSession(req.userId!, req.body?.filter ?? req.body ?? {}) }); }
  async deck(req: AuthRequest, res: Response) { res.json(await service.getDeck(req.userId!, String(req.params.sessionId))); }
  async swipe(req: AuthRequest, res: Response) { const swipe = await service.swipe(req.userId!, String(req.params.sessionId), String(req.body?.dishId ?? ''), req.body?.direction); res.status(201).json({ swipe }); }
}
export const soloSwipeController = new SoloSwipeController();
