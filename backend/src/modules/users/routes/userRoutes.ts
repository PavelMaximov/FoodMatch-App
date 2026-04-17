import { Router } from 'express';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { validateBody } from '../../../shared/validate';
import { userController } from '../controllers/userController';
import { confirmAvatarSchema } from '../dto/userSchemas';

const router = Router();

router.use(authMiddleware);
router.post('/avatar/confirm', validateBody(confirmAvatarSchema), asyncHandler(userController.confirmAvatar.bind(userController)));
router.delete('/avatar', asyncHandler(userController.deleteAvatar.bind(userController)));

export default router;
