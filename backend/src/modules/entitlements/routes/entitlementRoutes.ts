import { Router } from 'express';
import { authMiddleware, AuthRequest } from '../../../core/middleware/authMiddleware';
import { noStore } from '../../../core/middleware/noStore';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { entitlementService } from '../services/entitlementService';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
const router=Router();
router.get('/me',authMiddleware,noStore,asyncHandler(async(req:AuthRequest,res)=>{
  const userId = req.userId!;
  const value = await entitlementService.getEffectiveEntitlements(userId);
  const session = await domainRepositories.coupleSessions.findActiveForUser(userId);
  if (session?.status === 'active' && session.memberIds.includes(userId)) {
    value.features.sharedShoppingList = await entitlementService.canPairUseFeature(session, 'shared_shopping_list');
  }
  res.json(value);
}));
export default router;
