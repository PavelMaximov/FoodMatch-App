import { NextFunction, Request, Response } from 'express';
import { ZodSchema } from 'zod';

export function validateBody(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const parsed = schema.safeParse(req.body);
    if (process.env.DEBUG_SWIPE_PIPELINE === '1' && req.originalUrl.includes('/api/swipes')) {
      console.log('[debug][validateBody] url=%s success=%s', req.originalUrl, parsed.success);
    }
    if (!parsed.success) {
      if (process.env.DEBUG_SWIPE_PIPELINE === '1') {
        console.log('[debug][validateBody] errors=%o', parsed.error.flatten().fieldErrors);
      }
      res.status(400).json({ error: 'Validation error', details: parsed.error.flatten().fieldErrors });
      return;
    }
    req.body = parsed.data;
    next();
  };
}
