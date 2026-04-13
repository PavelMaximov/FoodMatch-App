import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { validateBody } from '../../../shared/validate';
import { swipeController } from '../controllers/swipeController';
import { createSwipeSchema } from '../dto/swipeSchemas';

const router = Router();

router.post('/', authMiddleware, validateBody(createSwipeSchema), asyncHandler(swipeController.create.bind(swipeController)));
router.get('/matches', authMiddleware, asyncHandler(swipeController.matches.bind(swipeController)));
router.get('/history', authMiddleware, asyncHandler(swipeController.history.bind(swipeController)));

export default router;
