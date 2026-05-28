import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { CoupleService } from '../services/coupleService';

const coupleService = new CoupleService();

export class CoupleController {
  async create(req: AuthRequest, res: Response) { res.status(201).json({ session: await coupleService.createSession(req.userId!) }); }
  async join(req: AuthRequest, res: Response) { res.json({ session: await coupleService.joinSession(req.userId!, req.body.inviteCode) }); }
  async me(req: AuthRequest, res: Response) { res.json({ session: await coupleService.getMyActiveSession(req.userId!) }); }
  async leave(req: AuthRequest, res: Response) { res.json(await coupleService.leaveSession(req.userId!)); }
  async reset(req: AuthRequest, res: Response) { res.json(await coupleService.resetSession(req.userId!)); }
  async getFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.getFilterState(req.userId!)); }
  async updateMyFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.updateMyFilterState(req.userId!, req.body)); }
  async confirmFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.confirmMyFilterState(req.userId!)); }
  async resetFilterState(req: AuthRequest, res: Response) { res.json(await coupleService.resetFilterState(req.userId!)); }
}

export const coupleController = new CoupleController();
