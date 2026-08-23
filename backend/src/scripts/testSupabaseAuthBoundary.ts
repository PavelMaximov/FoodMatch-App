import assert from 'node:assert/strict';
import type { NextFunction, Response } from 'express';

async function main(): Promise<void> {
  process.env.SUPABASE_URL ??= 'https://backend-test.supabase.co';
  process.env.SUPABASE_ANON_KEY ??= 'test-anon-key';
  process.env.SUPABASE_SERVICE_ROLE_KEY ??= 'test-service-role-key';

  const [{ authMiddleware }, { AppError }, { supabaseProfileService }, config, healthModule] = await Promise.all([
    import('../core/middleware/authMiddleware'),
    import('../core/errors/AppError'),
    import('../modules/auth/services/supabaseProfileService'),
    import('../config/supabase'),
    import('../modules/dev/configHealth'),
  ]);

  type AuthRequest = import('../core/middleware/authMiddleware').AuthRequest;
  async function runMiddleware(req: AuthRequest): Promise<unknown> {
    let nextValue: unknown;
    await authMiddleware(req, {} as Response, ((value?: unknown) => { nextValue = value; }) as NextFunction);
    return nextValue;
  }

  const missing = await runMiddleware({ headers: {} } as AuthRequest);
  assert(missing instanceof AppError && missing.statusCode === 401, 'missing bearer token must be rejected');
  assert.equal((missing as InstanceType<typeof AppError>).code, 'AUTH_TOKEN_MISSING');

  const originalVerify = supabaseProfileService.verifyAccessToken;
  const originalEnsure = supabaseProfileService.ensureProfile;
  const originalRuntime = supabaseProfileService.ensureMongoRuntimeUser;
  const warnings: string[] = [];
  const originalWarn = console.warn;
  try {
    console.warn = (...values: unknown[]) => warnings.push(values.join(' '));
    supabaseProfileService.verifyAccessToken = async () => { throw new AppError('Invalid token', 401); };
    const diagnosticToken = 'eyJhbGciOiJub25lIn0.eyJpc3MiOiJodHRwczovL2ZsdXR0ZXItcHJvamVjdC5zdXBhYmFzZS5jby9hdXRoL3YxIiwiYXVkIjoiYXV0aGVudGljYXRlZCIsInN1YiI6InVzZXIiLCJleHAiOjQxMDI0NDQ4MDB9.';
    const invalid = await runMiddleware({ headers: { authorization: `Bearer ${diagnosticToken}` } } as AuthRequest);
    assert(invalid instanceof AppError && invalid.statusCode === 401, 'invalid bearer token must be rejected');
    assert.equal((invalid as InstanceType<typeof AppError>).code, 'SUPABASE_TOKEN_INVALID');
    const diagnosticOutput = warnings.join('\n');
    assert(diagnosticOutput.includes('issHost=flutter-project.supabase.co'));
    assert(diagnosticOutput.includes('backend supabase host=backend-test.supabase.co'));
    assert(!diagnosticOutput.includes(diagnosticToken), 'diagnostics must not log the raw token');
    assert(!diagnosticOutput.includes(process.env.SUPABASE_SERVICE_ROLE_KEY!), 'diagnostics must not log keys');

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
    console.warn = originalWarn;
    supabaseProfileService.verifyAccessToken = originalVerify;
    supabaseProfileService.ensureProfile = originalEnsure;
    supabaseProfileService.ensureMongoRuntimeUser = originalRuntime;
  }

  assert.throws(() => config.normalizeSupabaseUrl('https://example.supabase.co/auth/v1'), /Invalid SUPABASE_URL/);
  assert.equal(healthModule.isConfigHealthEnabled('development'), true);
  assert.equal(healthModule.isConfigHealthEnabled('production'), false);
  const health = healthModule.getConfigHealthResponse();
  assert.equal(health.supabaseHost, 'backend-test.supabase.co');
  assert(!('anonKey' in health) && !('serviceRoleKey' in health), 'config health must not expose secrets');
  console.log('Supabase auth boundary checks passed');
}

void main();
