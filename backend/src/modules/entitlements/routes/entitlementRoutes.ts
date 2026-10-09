import { Router } from 'express';
import { authMiddleware, AuthRequest } from '../../../core/middleware/authMiddleware';
import { noStore } from '../../../core/middleware/noStore';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { entitlementService } from '../services/entitlementService';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
const router=Router();
router.get('/me',authMiddleware,noStore,asyncHandler(async(req:AuthRequest,res)=>{const userId=req.userId!,effective=await entitlementService.getEffectiveEntitlements(userId),session=await domainRepositories.coupleSessions.findActiveForUser(userId);if(session&&await entitlementService.canPairUseFeature(session,'shared_shopping_list'))effective.features.sharedShoppingList=true;res.json(effective);}));
export default router;
