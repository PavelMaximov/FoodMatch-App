import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { validateBody } from '../../../shared/validate';
import { coupleController } from '../controllers/coupleController';
import { joinCoupleSchema } from '../dto/coupleSchemas';

const router = Router();

router.post('/create', authMiddleware, asyncHandler(coupleController.create.bind(coupleController)));
router.post('/join', authMiddleware, validateBody(joinCoupleSchema), asyncHandler(coupleController.join.bind(coupleController)));
router.get('/me', authMiddleware, asyncHandler(coupleController.me.bind(coupleController)));
router.post('/leave', authMiddleware, asyncHandler(coupleController.leave.bind(coupleController)));
router.post('/reset', authMiddleware, asyncHandler(coupleController.reset.bind(coupleController)));

export default router;
