import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { SoloSwipeService } from '../services/soloSwipeService';
const service = new SoloSwipeService();
export class SoloSwipeController {
  async active(req: AuthRequest, res: Response) { res.json({ session: await service.getActive(req.user!.id) }); }
  async resumable(req: AuthRequest, res: Response) { res.json({ session: await service.getResumable(req.user!.id) }); }
  async create(req: AuthRequest, res: Response) { const session=await service.createSession(req.user!.id, req.body?.filter ?? req.body ?? {});res.status(session.resumedExisting?200:201).json({ session }); }
  async updateFilter(req: AuthRequest, res: Response) { res.json({ session: await service.updateActiveFilter(req.user!.id, req.body?.filter ?? req.body ?? {}) }); }
  async abandon(req: AuthRequest, res: Response) { res.json(await service.abandonActive(req.user!.id)); }
  async deck(req: AuthRequest, res: Response) { res.json(await service.getDeck(req.user!.id, String(req.params.sessionId))); }
  async swipe(req: AuthRequest, res: Response) { const swipe = await service.swipe(req.user!.id, String(req.params.sessionId), String(req.body?.dishId ?? ''), req.body?.direction); res.status(201).json({ swipe }); }
  async undo(req: AuthRequest, res: Response) { res.json(await service.undo(req.user!.id, String(req.params.sessionId))); }
}
export const soloSwipeController = new SoloSwipeController();
