import { Router } from 'express';
import { z } from 'zod';
import { authMiddleware, AuthRequest } from '../../core/middleware/authMiddleware';
import { AppError } from '../../core/errors/AppError';
import { PurchaseVerificationService } from './purchaseVerificationService';
import { NotConfiguredEntitlementProjector, PostgresStorePurchaseRepository } from './storePurchaseRepository';

// Strict allowlist: client ownership, tier, status, expiry and isPremium rejected.
export const purchaseEvidenceSchema = z.object({
  provider: z.enum(['apple', 'google']),
  productId: z.string().trim().min(1).max(255),
  purchaseEvidence: z.string().min(1).max(100000),
}).strict();
export function createPurchaseRoutes(service = new PurchaseVerificationService(
  new PostgresStorePurchaseRepository(), new NotConfiguredEntitlementProjector(),
)) {
  const router = Router();
  router.use(authMiddleware);
  for (const path of ['/verify', '/restore/sync']) {
    router.post(path, async (req: AuthRequest, res, next) => {
      try {
        if (!req.userId) throw new AppError('Unauthorized', 401, 'AUTH_TOKEN_MISSING');
        const evidence = purchaseEvidenceSchema.parse(req.body);
        res.json(await service.verifyAndSync(req.userId, evidence));
      } catch (error) { next(error); }
    });
  }
  return router;
}
export default createPurchaseRoutes();
