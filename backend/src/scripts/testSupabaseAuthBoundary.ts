import assert from 'node:assert/strict';
import { NextFunction, Response } from 'express';
import { AuthRequest, authMiddleware } from '../core/middleware/authMiddleware';
import { AppError } from '../core/errors/AppError';
import { supabaseProfileService } from '../modules/auth/services/supabaseProfileService';

async function runMiddleware(req: AuthRequest): Promise<unknown> {
  let nextValue: unknown;
  await authMiddleware(req, {} as Response, ((value?: unknown) => { nextValue = value; }) as NextFunction);
  return nextValue;
}

async function main(): Promise<void> {
  const missing = await runMiddleware({ headers: {} } as AuthRequest);
  assert(missing instanceof AppError && missing.statusCode === 401, 'missing bearer token must be rejected');

  const originalVerify = supabaseProfileService.verifyAccessToken;
  const originalEnsure = supabaseProfileService.ensureProfile;
  const originalRuntime = supabaseProfileService.ensureMongoRuntimeUser;
  try {
    supabaseProfileService.verifyAccessToken = async () => { throw new AppError('Invalid token', 401); };
    const invalid = await runMiddleware({ headers: { authorization: 'Bearer invalid' } } as AuthRequest);
    assert(invalid instanceof AppError && invalid.statusCode === 401, 'invalid bearer token must be rejected');

    const authUser = { id: '7d3d66bd-5b7e-465d-a1dd-2f553f58db61', email: 'qa@example.com' } as never;
    const profile = {
      id: '7d3d66bd-5b7e-465d-a1dd-2f553f58db61', email: 'qa@example.com', displayName: 'QA',
      avatarUrl: null, measurementSystemPreference: 'auto' as const, createdAt: 'now', updatedAt: 'now',
    };
    supabaseProfileService.verifyAccessToken = async () => authUser;
    supabaseProfileService.ensureProfile = async () => profile;
    supabaseProfileService.ensureMongoRuntimeUser = async () => ({ id: '507f1f77bcf86cd799439011' } as never);
    const request = { headers: { authorization: 'Bearer verified' } } as AuthRequest;
    const accepted = await runMiddleware(request);
    assert.equal(accepted, undefined);
    assert.equal(request.userId, '507f1f77bcf86cd799439011');
    assert.equal(request.user?.id, profile.id);
  } finally {
    supabaseProfileService.verifyAccessToken = originalVerify;
    supabaseProfileService.ensureProfile = originalEnsure;
    supabaseProfileService.ensureMongoRuntimeUser = originalRuntime;
  }
  console.log('Supabase auth boundary checks passed');
}

void main();
