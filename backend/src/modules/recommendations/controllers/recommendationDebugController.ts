import { Response } from 'express';
import { AuthRequest } from '../../../core/middleware/authMiddleware';
import { RecommendationDebugService } from '../services/recommendationDebugService';

const service = new RecommendationDebugService();

export class RecommendationDebugController {
  async solo(req: AuthRequest, res: Response) {
    const result = await service.solo(req.userId!, String(req.params.sessionId), req.query.includeDishes === 'true');
    res.json(result);
  }

  async pair(req: AuthRequest, res: Response) {
    const result = await service.pair(req.userId!, String(req.params.sessionId), req.query.includeDishes === 'true');
    res.json(result);
  }
}
