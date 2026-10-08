import { Router } from 'express';
import { authMiddleware, AuthRequest } from '../../../core/middleware/authMiddleware';
import { noStore } from '../../../core/middleware/noStore';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { entitlementService } from '../services/entitlementService';
const router=Router();
router.get('/me',authMiddleware,noStore,asyncHandler(async(req:AuthRequest,res)=>{res.json(await entitlementService.getEffectiveEntitlements(req.userId!));}));
export default router;
