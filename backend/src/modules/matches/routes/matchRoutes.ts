import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { matchController } from '../controllers/matchController';
import { noStore } from '../../../core/middleware/noStore';

const router = Router();

router.get('/history', authMiddleware, noStore, asyncHandler(matchController.history.bind(matchController)));
router.get('/history/:sessionId', authMiddleware, noStore, asyncHandler(matchController.historySession.bind(matchController)));
router.get('/', authMiddleware, asyncHandler(matchController.list.bind(matchController)));

export default router;
