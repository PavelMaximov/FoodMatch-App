import { Router, RequestHandler } from 'express';
import { authMiddleware, AuthRequest } from '../../../core/middleware/authMiddleware';
import { AppError } from '../../../core/errors/AppError';
import { noStore } from '../../../core/middleware/noStore';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { EntitlementService, entitlementService } from '../services/entitlementService';
import { CoupleSessionRecord } from '../../../domain/repositories/types';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';

interface Dependencies {
  entitlements: Pick<EntitlementService, 'resolveEffectiveEntitlements' | 'resolvePairSharedShoppingList'>;
  findActivePair: (userId: string) => Promise<CoupleSessionRecord | null>;
  authenticate: RequestHandler;
}

export function createEntitlementRouter(overrides: Partial<Dependencies> = {}) {
  const dependencies: Dependencies = {
    entitlements: entitlementService,
    findActivePair: (userId) => domainRepositories.coupleSessions.findActiveForUser(userId),
    authenticate: authMiddleware,
    ...overrides,
  };
  const router = Router();
  router.get('/me', dependencies.authenticate, noStore, asyncHandler(async (req: AuthRequest, res) => {
    try {
      const userId = req.userId!;
      const value = await dependencies.entitlements.resolveEffectiveEntitlements(userId);
      const session = await dependencies.findActivePair(userId);
      if (session?.status === 'active' && session.memberIds.includes(userId)) {
        // Any member-resolution failure must abort the response, not project a
        // normal Free account that would enable external ad requests.
        value.features.sharedShoppingList = await dependencies.entitlements.resolvePairSharedShoppingList(session);
      }
      res.json(value);
    } catch {
      throw new AppError('Entitlement resolution is temporarily unavailable.', 503, 'ENTITLEMENT_RESOLUTION_UNAVAILABLE');
    }
  }));
  return router;
}

export default createEntitlementRouter();
