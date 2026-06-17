import { NextFunction, Request, Response } from 'express';
import mongoose from 'mongoose';
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

  if (err instanceof mongoose.Error.ValidationError) {
    res.status(400).json({
      error: 'Validation failed',
      message: 'Validation failed',
      code: 'VALIDATION_ERROR'
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

function isDuplicateKeyError(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && (error as { code?: number }).code === 11000;
}
