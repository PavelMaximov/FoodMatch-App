import assert from 'node:assert/strict';
import type { NextFunction, Response } from 'express';
import { errorHandler } from '../core/middleware/errorHandler';

async function main(): Promise<void> {
  process.env.SUPABASE_URL ??= 'https://backend-test.supabase.co';
  process.env.SUPABASE_ANON_KEY ??= 'test-anon-key';
  process.env.SUPABASE_SERVICE_ROLE_KEY ??= 'test-service-role-key';
  process.env.SUPABASE_DB_URL ??= 'postgresql://postgres:secret@127.0.0.1:54322/postgres';

  const [{ authMiddleware }, { AppError }, { supabaseProfileService, SupabaseProfileService }, config, healthModule] = await Promise.all([
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

  const profileQueries: Array<{ text: string; values: readonly unknown[] }> = [];
  const profileService = new SupabaseProfileService((async (text: string, values: readonly unknown[] = []) => {
    profileQueries.push({ text, values });
    return { rows: [{
      id: '7d3d66bd-5b7e-465d-a1dd-2f553f58db61', email: 'qa@example.com',
      display_name: 'QA user', avatar_url: null, measurement_system_preference: 'auto',
      created_at: 'now', updated_at: 'now'
    }], rowCount: 1 } as never;
  }) as never);
  const ensured = await profileService.ensureProfile({
    id: '7d3d66bd-5b7e-465d-a1dd-2f553f58db61', email: 'QA@Example.com',
    user_metadata: { display_name: 'QA user' }
  } as never);
  assert.equal(ensured.id, '7d3d66bd-5b7e-465d-a1dd-2f553f58db61');
  assert.equal(profileQueries.length, 1, 'verified user profile must be upserted through the domain database');
  assert.match(profileQueries[0].text, /insert into public\.profiles/);
  assert.deepEqual(profileQueries[0].values.slice(0, 3), [ensured.id, 'qa@example.com', 'QA user']);

  let errorStatus = 0;
  let errorBody: Record<string, unknown> = {};
  errorHandler(Object.assign(new Error('fk'), {
    code: '23503', constraint: 'solo_swipe_sessions_user_id_fkey',
    detail: 'Key (user_id)=(7d3d66bd-5b7e-465d-a1dd-2f553f58db61) is not present in table \"profiles\".'
  }), {} as never, {
    status(code: number) { errorStatus = code; return this; },
    json(body: Record<string, unknown>) { errorBody = body; return this; }
  } as never, (() => undefined) as never);
  assert.equal(errorStatus, 500);
  assert.equal(errorBody.code, 'SUPABASE_PROFILE_MISSING');

  assert.throws(() => config.normalizeSupabaseUrl('https://example.supabase.co/auth/v1'), /Invalid SUPABASE_URL/);
  assert.equal(healthModule.isConfigHealthEnabled('development'), true);
  assert.equal(healthModule.isConfigHealthEnabled('production'), false);
  const health = healthModule.getConfigHealthResponse();
  assert.equal(health.supabaseHost, 'backend-test.supabase.co');
  assert(!('anonKey' in health) && !('serviceRoleKey' in health), 'config health must not expose secrets');
  assert.equal(health.authLooksHosted, true);
  assert.equal(health.dbLooksLocal, true);
  assert.equal(health.possibleEnvMismatch, true, 'hosted Auth plus local DB must be diagnosed');
  assert(!JSON.stringify(health).includes('secret'), 'config health must not expose the database password');
  console.log('Supabase auth boundary checks passed');
}

void main();
