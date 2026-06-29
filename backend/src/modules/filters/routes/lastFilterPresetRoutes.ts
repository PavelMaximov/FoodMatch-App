import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { lastFilterPresetController } from '../controllers/lastFilterPresetController';
const router = Router();
router.get('/last', authMiddleware, asyncHandler(lastFilterPresetController.get.bind(lastFilterPresetController)));
router.put('/last', authMiddleware, asyncHandler(lastFilterPresetController.put.bind(lastFilterPresetController)));
export default router;
