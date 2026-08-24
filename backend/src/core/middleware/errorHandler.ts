import { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import { AppError } from '../errors/AppError';

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof SyntaxError && 'body' in err) {
    res.status(400).json({ error: 'Invalid JSON payload.', message: 'Invalid JSON payload.', code: 'INVALID_JSON' });
    return;
  }

  if ('type' in err && (err as { type?: string }).type === 'entity.too.large') {
    res.status(413).json({ error: 'This file is too large.', message: 'This file is too large.', code: 'PAYLOAD_TOO_LARGE' });
    return;
  }

  if (err instanceof ZodError) {
    res.status(400).json({ error: 'Validation error', message: 'Please check your input and try again.', code: 'VALIDATION_ERROR', details: err.flatten().fieldErrors });
    return;
  }

  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: err.message,
      message: err.message,
      ...(err.code ? { code: err.code } : {}),
      ...(err.details ?? {})
    });
    return;
  }


  if (isDuplicateKeyError(err)) {
    console.warn('[ErrorHandler] duplicate key conflict', err);
    res.status(409).json({
      error: 'Conflict',
      message: 'This item already exists.',
      code: 'CONFLICT'
    });
    return;
  }

  if (isMissingSupabaseProfileError(err)) {
    const userId = profileUserId(err) ?? 'unknown';
    console.error(`[AuthProfile] missing profile before domain write user=${userId}`);
    console.error('[AuthProfile] hint=Run repair:supabase-profiles or verify profile upsert uses the same DB as domain repositories.');
    res.status(500).json({
      error: 'User profile is not ready',
      message: 'User profile is not ready',
      code: 'SUPABASE_PROFILE_MISSING'
    });
    return;
  }

  if (err.message === 'CORS origin not allowed') {
    res.status(403).json({ error: 'You do not have permission to do this.', message: 'You do not have permission to do this.', code: 'CORS_ORIGIN_DENIED' });
    return;
  }

  console.error(err);
  res.status(500).json({
    error: 'Server is not available right now. Please try again later.',
    message: 'Server is not available right now. Please try again later.',
    code: 'INTERNAL_SERVER_ERROR'
  });
}

function isMissingSupabaseProfileError(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const postgres = error as { code?: string; constraint?: string; detail?: string };
  return postgres.code === '23503' && Boolean(
    postgres.constraint?.includes('user_id_fkey') ||
    postgres.constraint?.includes('created_by_fkey') ||
    postgres.detail?.includes('is not present in table "profiles"')
  );
}

function profileUserId(error: unknown): string | null {
  const detail = typeof error === 'object' && error !== null && 'detail' in error
    ? String((error as { detail?: unknown }).detail ?? '') : '';
  return detail.match(/Key \([^)]*\)=\(([^)]+)\)/)?.[1] ?? null;
}

function isDuplicateKeyError(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && (error as { code?: number }).code === 11000;
}
