import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { coupleRateLimiter } from '../../../core/middleware/rateLimiters';
import { validateBody } from '../../../shared/validate';
import { noStore } from '../../../core/middleware/noStore';
import { coupleController } from '../controllers/coupleController';
import { joinCoupleSchema, updateCoupleFilterStateSchema } from '../dto/coupleSchemas';

const router = Router();

router.post('/create', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.create.bind(coupleController)));
router.post('/join', authMiddleware, coupleRateLimiter, validateBody(joinCoupleSchema), asyncHandler(coupleController.join.bind(coupleController)));
router.get('/me', noStore, authMiddleware, asyncHandler(coupleController.me.bind(coupleController)));
router.post('/leave', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.leave.bind(coupleController)));
router.post('/reset', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.reset.bind(coupleController)));

router.post('/deck/prepare', noStore, authMiddleware, coupleRateLimiter, asyncHandler(coupleController.prepareDeck.bind(coupleController)));
router.get('/deck', noStore, authMiddleware, asyncHandler(coupleController.getDeck.bind(coupleController)));
router.post('/deck/reset', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.resetDeck.bind(coupleController)));

router.get('/filter-state', noStore, authMiddleware, asyncHandler(coupleController.getFilterState.bind(coupleController)));
router.put('/filter-state/me', noStore, authMiddleware, coupleRateLimiter, validateBody(updateCoupleFilterStateSchema), asyncHandler(coupleController.updateMyFilterState.bind(coupleController)));
router.post('/filter-state/confirm', noStore, authMiddleware, coupleRateLimiter, asyncHandler(coupleController.confirmFilterState.bind(coupleController)));
router.post('/filter-state/reset', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.resetFilterState.bind(coupleController)));

export default router;
