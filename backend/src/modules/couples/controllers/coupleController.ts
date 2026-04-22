import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { CoupleService } from '../services/coupleService';

const coupleService = new CoupleService();

export class CoupleController {
  async create(req: AuthRequest, res: Response) {
    const session = await coupleService.createSession(req.userId!);
    res.status(201).json({ session });
  }

  async join(req: AuthRequest, res: Response) {
    const session = await coupleService.joinSession(req.userId!, req.body.inviteCode);
    res.json({ session });
  }

  async me(req: AuthRequest, res: Response) {
    const session = await coupleService.getMyActiveSession(req.userId!);
    res.json({ session });
  }

  async leave(req: AuthRequest, res: Response) {
    const result = await coupleService.leaveSession(req.userId!);
    res.json(result);
  }

  async reset(req: AuthRequest, res: Response) {
    const result = await coupleService.resetSession(req.userId!);
    res.json(result);
  }

  async getFilterState(req: AuthRequest, res: Response) {
    const filterState = await coupleService.getFilterState(req.userId!);
    res.json({ filterState });
  }

  async updateFilterState(req: AuthRequest, res: Response) {
    const filterState = await coupleService.updateFilterState(req.userId!, req.body);
    res.json({ filterState });
  }

  async clearFilterState(req: AuthRequest, res: Response) {
    const result = await coupleService.clearFilterState(req.userId!);
    res.json(result);
  }
}

export const coupleController = new CoupleController();
