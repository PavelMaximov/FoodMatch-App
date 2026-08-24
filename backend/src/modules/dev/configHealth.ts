import { getSupabaseConfigHealth } from '../../config/supabase';

export function isConfigHealthEnabled(nodeEnv: string): boolean {
  return nodeEnv !== 'production';
}

export function getConfigHealthResponse() {
  const health = getSupabaseConfigHealth();
  return {
    api: 'ok',
    supabaseHost: health.supabaseHost,
    supabaseUrlIsLocal: health.supabaseUrlIsLocal,
    hasAnonKey: health.hasAnonKey,
    hasServiceRoleKey: health.hasServiceRoleKey,
    hasDbUrl: health.hasDbUrl,
    authHost: health.authHost,
    dbHost: health.dbHost,
    authLooksHosted: health.authLooksHosted,
    dbLooksLocal: health.dbLooksLocal,
    possibleEnvMismatch: health.possibleEnvMismatch,
    mongoRuntime: 'disabled',
  };
}
