import { NextFunction, Request, Response } from 'express';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';

const tooManyAttempts = 'Too many attempts. Please wait a bit and try again.';

function jsonHandler(_req: Request, res: Response) {
  res.status(429).json({ error: tooManyAttempts, message: tooManyAttempts, code: 'RATE_LIMITED' });
}


const getRateLimitKey = (req: Request): string => {
  const userId = (req as any).user?.id || (req as any).user?._id || (req as any).userId;

  if (userId) {
    return `user:${String(userId)}`;
  }

  return `ip:${ipKeyGenerator(req.ip ?? 'unknown')}`;
};

export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonHandler
});

export const loginRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  handler: jsonHandler
});

export const writeRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => !['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method),
  handler: jsonHandler
});

export const swipeRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonHandler
});

export const coupleRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 60,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonHandler
});

export const uploadRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonHandler
});

export function applyWriteRateLimiter(req: Request, res: Response, next: NextFunction): void {
  writeRateLimiter(req, res, next);
}


export const resendVerificationRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 3,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: getRateLimitKey,
  handler: jsonHandler
});

export const verifyEmailRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  handler: jsonHandler
});
