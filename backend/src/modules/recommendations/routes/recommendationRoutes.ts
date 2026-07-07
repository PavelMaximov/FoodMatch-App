import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { RecommendationDebugController } from '../controllers/recommendationDebugController';

const router = Router();
const controller = new RecommendationDebugController();

router.get('/debug/solo/:sessionId', authMiddleware, asyncHandler(controller.solo.bind(controller)));
router.get('/debug/pair/:sessionId', authMiddleware, asyncHandler(controller.pair.bind(controller)));

export default router;
