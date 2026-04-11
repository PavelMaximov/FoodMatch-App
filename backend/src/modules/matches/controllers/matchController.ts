import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { AppError } from '../../../core/errors/AppError';
import { CoupleService } from '../../couples/services/coupleService';
import { MatchService } from '../services/matchService';

const matchService = new MatchService();
const coupleService = new CoupleService();

export class MatchController {
  async list(req: AuthRequest, res: Response) {
    const session = await coupleService.getMyActiveSession(req.userId!);
    if (!session) {
      throw new AppError('No active session found', 404);
    }

    const matches = await matchService.listForCouple(session.id);
    res.json({ matches });
  }
}

export const matchController = new MatchController();
