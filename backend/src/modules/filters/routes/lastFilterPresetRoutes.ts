import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { noStore } from '../../../core/middleware/noStore';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { lastFilterPresetController } from '../controllers/lastFilterPresetController';
const router = Router();
router.get('/last', authMiddleware, noStore, asyncHandler(lastFilterPresetController.get.bind(lastFilterPresetController)));
router.put('/last', authMiddleware, noStore, asyncHandler(lastFilterPresetController.put.bind(lastFilterPresetController)));
export default router;
