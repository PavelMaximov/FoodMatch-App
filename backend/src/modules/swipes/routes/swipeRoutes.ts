import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { noStore } from '../../../core/middleware/noStore';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { swipeRateLimiter } from '../../../core/middleware/rateLimiters';
import { validateBody } from '../../../shared/validate';
import { swipeController } from '../controllers/swipeController';
import { createSwipeSchema } from '../dto/swipeSchemas';

const router = Router();

router.post('/', authMiddleware, swipeRateLimiter, validateBody(createSwipeSchema), asyncHandler(swipeController.create.bind(swipeController)));
router.get('/matches', authMiddleware, noStore, asyncHandler(swipeController.matches.bind(swipeController)));
router.get('/history', authMiddleware, asyncHandler(swipeController.history.bind(swipeController)));

export default router;
