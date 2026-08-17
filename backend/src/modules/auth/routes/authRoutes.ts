import { Router } from 'express';
import { asyncHandler } from '../../../core/utils/asyncHandler';
import { authMiddleware } from '../../../core/middleware/authMiddleware';
import { authRateLimiter, loginRateLimiter, resendVerificationRateLimiter, verifyEmailRateLimiter } from '../../../core/middleware/rateLimiters';
import { validateBody } from '../../../shared/validate';
import { authController } from '../controllers/authController';
import { loginSchema, measurementPreferenceSchema, registerSchema } from '../dto/authSchemas';

const router = Router();

router.post('/register', authRateLimiter, validateBody(registerSchema), asyncHandler(authController.register.bind(authController)));
router.post('/login', loginRateLimiter, validateBody(loginSchema), asyncHandler(authController.login.bind(authController)));
router.post('/refresh', authRateLimiter, asyncHandler(authController.refresh.bind(authController)));
router.post('/logout', asyncHandler(authController.logout.bind(authController)));
router.post('/logout-all', authMiddleware, asyncHandler(authController.logoutAll.bind(authController)));
router.get('/me', authMiddleware, asyncHandler(authController.me.bind(authController)));
router.patch('/me/preferences', authMiddleware, validateBody(measurementPreferenceSchema), asyncHandler(authController.updatePreferences.bind(authController)));
router.post('/resend-verification', authMiddleware, resendVerificationRateLimiter, asyncHandler(authController.resendVerification.bind(authController)));
router.post('/verify-email', verifyEmailRateLimiter, asyncHandler(authController.verifyEmail.bind(authController)));
router.get('/verify-email', verifyEmailRateLimiter, asyncHandler(authController.verifyEmail.bind(authController)));

export default router;
