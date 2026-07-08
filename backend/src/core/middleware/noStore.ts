import { NextFunction, Request, Response } from 'express';

export function noStore(_req: Request, res: Response, next: NextFunction) {
  res.set({
    'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
    Pragma: 'no-cache',
    Expires: '0',
    'Surrogate-Control': 'no-store'
  });
  res.removeHeader('ETag');
  next();
}
