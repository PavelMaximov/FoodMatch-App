import { NextFunction, Router, Response } from 'express';
import { uploadRateLimiter } from '../../core/middleware/rateLimiters';
import { authMiddleware, AuthRequest } from '../../core/middleware/authMiddleware';
import { asyncHandler } from '../../core/utils/asyncHandler';
import { imageUpload, mapMulterError, uploadFieldName } from './middleware/uploadMiddleware';
import { uploadController } from './uploadController';

const router = Router();

router.use(authMiddleware);

function singleImage(req: AuthRequest, res: Response, next: NextFunction): void {
  imageUpload.single(uploadFieldName)(req, res, (error: unknown) => {
    next(error ? mapMulterError(error) : undefined);
  });
}

router.post('/avatar', uploadRateLimiter, singleImage, asyncHandler(uploadController.uploadAvatar.bind(uploadController)));
router.delete('/avatar', asyncHandler(uploadController.deleteAvatar.bind(uploadController)));
router.post('/custom-dish-image', uploadRateLimiter, singleImage, asyncHandler(uploadController.uploadCustomDishImage.bind(uploadController)));

export default router;
