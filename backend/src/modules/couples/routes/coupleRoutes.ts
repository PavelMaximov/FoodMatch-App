import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { validateBody } from '../../../shared/validate';
import { coupleController } from '../controllers/coupleController';
import { joinCoupleSchema, updateCoupleFilterStateSchema } from '../dto/coupleSchemas';

const router = Router();

router.post('/create', authMiddleware, asyncHandler(coupleController.create.bind(coupleController)));
router.post('/join', authMiddleware, validateBody(joinCoupleSchema), asyncHandler(coupleController.join.bind(coupleController)));
router.get('/me', authMiddleware, asyncHandler(coupleController.me.bind(coupleController)));
router.post('/leave', authMiddleware, asyncHandler(coupleController.leave.bind(coupleController)));
router.post('/reset', authMiddleware, asyncHandler(coupleController.reset.bind(coupleController)));

router.post('/deck/prepare', authMiddleware, asyncHandler(coupleController.prepareDeck.bind(coupleController)));
router.get('/deck', authMiddleware, asyncHandler(coupleController.getDeck.bind(coupleController)));
router.post('/deck/reset', authMiddleware, asyncHandler(coupleController.resetDeck.bind(coupleController)));

router.get('/filter-state', authMiddleware, asyncHandler(coupleController.getFilterState.bind(coupleController)));
router.put('/filter-state/me', authMiddleware, validateBody(updateCoupleFilterStateSchema), asyncHandler(coupleController.updateMyFilterState.bind(coupleController)));
router.post('/filter-state/confirm', authMiddleware, asyncHandler(coupleController.confirmFilterState.bind(coupleController)));
router.post('/filter-state/reset', authMiddleware, asyncHandler(coupleController.resetFilterState.bind(coupleController)));

export default router;
