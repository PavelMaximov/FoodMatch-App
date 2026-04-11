import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { matchController } from '../controllers/matchController';

const router = Router();

router.get('/', authMiddleware, asyncHandler(matchController.list.bind(matchController)));

export default router;
