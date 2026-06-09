import { NextFunction, Request, Response } from 'express';
import mongoose from 'mongoose';
import { AppError } from '../errors/AppError';

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
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
