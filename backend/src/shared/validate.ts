import { NextFunction, Request, Response } from 'express';
import { ZodSchema } from 'zod';

export function validateBody(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const isPairFilterState = req.originalUrl.includes('/couples/filter-state/me');
    if (isPairFilterState && process.env.NODE_ENV !== 'production') {
      const body = typeof req.body === 'object' && req.body !== null ? req.body as Record<string, unknown> : {};
      const payload = (body.choices ?? body.filter ?? body.filters ?? body) as Record<string, unknown>;
      console.info(`[PairFilterState] incoming payload keys=${Object.keys(payload).sort().join(',')}`);
      console.info('[PairFilterState] selectedCategories=%o', payload.selectedCategories ?? null);
      console.info('[PairFilterState] legacy dishRegisters=%o', payload.dishRegisters ?? null);
      console.info('[PairFilterState] cuisine=%o', payload.selectedCuisines ?? payload.cuisines ?? payload.cuisine ?? null);
    }
    const parsed = schema.safeParse(req.body);
    if (process.env.DEBUG_SWIPE_PIPELINE === '1' && req.originalUrl.includes('/api/swipes')) {
      console.log('[debug][validateBody] url=%s success=%s', req.originalUrl, parsed.success);
    }
    if (!parsed.success) {
      const flattened = parsed.error.flatten();
      const details: Record<string, string | string[]> = {};
      for (const [field, messages] of Object.entries(flattened.fieldErrors)) {
        if (messages?.length) details[field] = messages;
      }
      if (flattened.formErrors.length > 0) details.request = flattened.formErrors;
      if (isPairFilterState && process.env.NODE_ENV !== 'production') console.info('[PairFilterState] validation result=failed details=%o', details);
      if (process.env.DEBUG_SWIPE_PIPELINE === '1') {
        console.log('[debug][validateBody] errors=%o', parsed.error.flatten().fieldErrors);
      }
      res.status(400).json({ error: 'Validation error', message: 'Please check your filters and try again.', code: 'VALIDATION_ERROR', details });
      return;
    }
    if (isPairFilterState && process.env.NODE_ENV !== 'production') console.info('[PairFilterState] validation result=ok details={}');
    req.body = parsed.data;
    next();
  };
}
