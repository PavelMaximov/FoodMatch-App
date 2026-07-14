import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { noStore } from '../../../core/middleware/noStore';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { coupleRateLimiter } from '../../../core/middleware/rateLimiters';
import { validateBody } from '../../../shared/validate';
import { coupleController } from '../controllers/coupleController';
import { joinCoupleSchema, updateCoupleFilterStateSchema } from '../dto/coupleSchemas';

const router = Router();

router.post('/create', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.create.bind(coupleController)));
router.post('/join', authMiddleware, coupleRateLimiter, validateBody(joinCoupleSchema), asyncHandler(coupleController.join.bind(coupleController)));
router.get('/me', authMiddleware, noStore, asyncHandler(coupleController.me.bind(coupleController)));
router.post('/leave', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.leave.bind(coupleController)));
router.post('/reset', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.reset.bind(coupleController)));
router.post('/continue-as-before', authMiddleware, noStore, coupleRateLimiter, asyncHandler(coupleController.continueAsBefore.bind(coupleController)));
router.get('/invitations/pending', authMiddleware, noStore, asyncHandler(coupleController.pendingInvitations.bind(coupleController)));
router.post('/invitations/:id/accept', authMiddleware, noStore, coupleRateLimiter, asyncHandler(coupleController.acceptInvitation.bind(coupleController)));
router.post('/invitations/:id/decline', authMiddleware, noStore, coupleRateLimiter, asyncHandler(coupleController.declineInvitation.bind(coupleController)));

router.post('/deck/prepare', authMiddleware, noStore, coupleRateLimiter, asyncHandler(coupleController.prepareDeck.bind(coupleController)));
router.get('/deck', authMiddleware, noStore, asyncHandler(coupleController.getDeck.bind(coupleController)));
router.post('/deck/reset', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.resetDeck.bind(coupleController)));

router.get('/filter-state', authMiddleware, noStore, asyncHandler(coupleController.getFilterState.bind(coupleController)));
router.put('/filter-state/me', authMiddleware, noStore, coupleRateLimiter, validateBody(updateCoupleFilterStateSchema), asyncHandler(coupleController.updateMyFilterState.bind(coupleController)));
router.post('/filter-state/confirm', authMiddleware, noStore, coupleRateLimiter, asyncHandler(coupleController.confirmFilterState.bind(coupleController)));
router.post('/filter-state/reset', authMiddleware, coupleRateLimiter, asyncHandler(coupleController.resetFilterState.bind(coupleController)));

export default router;
