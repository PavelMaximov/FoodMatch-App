import { Router } from 'express';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { authRateLimiter, loginRateLimiter } from '../../../core/middleware/rateLimiters';
import { validateBody } from '../../../shared/validate';
import { authController } from '../controllers/authController';
import { loginSchema, registerSchema } from '../dto/authSchemas';

const router = Router();

router.post('/register', authRateLimiter, validateBody(registerSchema), asyncHandler(authController.register.bind(authController)));
router.post('/login', authRateLimiter, loginRateLimiter, validateBody(loginSchema), asyncHandler(authController.login.bind(authController)));
router.get('/me', authMiddleware, asyncHandler(authController.me.bind(authController)));

export default router;
