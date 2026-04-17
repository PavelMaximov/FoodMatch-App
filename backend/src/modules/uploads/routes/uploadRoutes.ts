import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { validateBody } from '../../../shared/validate';
import { uploadController } from '../controllers/uploadController';
import { uploadUrlSchema } from '../dto/uploadSchemas';

const router = Router();

router.use(authMiddleware);
router.post('/avatar-url', validateBody(uploadUrlSchema), asyncHandler(uploadController.getAvatarUploadUrl.bind(uploadController)));
router.post('/dish-image-url', validateBody(uploadUrlSchema), asyncHandler(uploadController.getDishImageUploadUrl.bind(uploadController)));

export default router;
