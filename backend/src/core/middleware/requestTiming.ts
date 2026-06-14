import { NextFunction, Response } from 'express';
import { AuthRequest } from './authMiddleware';

const DEFAULT_SLOW_MS = 500;
const DECK_PREPARE_SLOW_MS = 1500;
const UPLOAD_SLOW_MS = 3000;

function slowThresholdFor(path: string): number {
  if (path.includes('/couples/deck/prepare')) return DECK_PREPARE_SLOW_MS;
  if (path.includes('/uploads/')) return UPLOAD_SLOW_MS;
  return DEFAULT_SLOW_MS;
}

export function requestTiming(req: AuthRequest, res: Response, next: NextFunction): void {
  if (process.env.NODE_ENV === 'production') {
    next();
    return;
  }

  const startedAt = process.hrtime.bigint();

  res.on('finish', () => {
    if (!req.originalUrl.startsWith('/api')) return;

    const durationMs = Number((process.hrtime.bigint() - startedAt) / BigInt(1_000_000));
    const thresholdMs = slowThresholdFor(req.originalUrl);
    const isSlow = durationMs > thresholdMs;
    const user = req.userId ? ` user=${req.userId}` : '';
    const marker = isSlow ? '[API:SLOW]' : '[API]';

    console.log(`${marker} ${req.method} ${req.originalUrl} ${res.statusCode} ${durationMs}ms${user}`);
  });

  next();
}
