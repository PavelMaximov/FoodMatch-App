import { z } from 'zod';

const optionalUrl = z.string().url().optional();
const invalidUrlMessage = 'Invalid SUPABASE_URL. Use the Supabase project root URL, for example https://<project-ref>.supabase.co. Do not include /rest/v1, /auth/v1, or /api.';

export function normalizeSupabaseUrl(value: string | undefined): string {
  if (!value?.trim()) throw new Error(invalidUrlMessage);
  let url: URL;
  try {
    url = new URL(value.trim());
  } catch {
    throw new Error(invalidUrlMessage);
  }
  if (!['http:', 'https:'].includes(url.protocol) || !url.host || (url.pathname !== '/' && url.pathname !== '') || url.search || url.hash || url.username || url.password) {
    throw new Error(invalidUrlMessage);
  }
  return url.origin;
}

export const supabaseConfig = {
  url: normalizeSupabaseUrl(process.env.SUPABASE_URL),
  anonKey: process.env.SUPABASE_ANON_KEY || undefined,
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || undefined,
  databaseUrl: optionalUrl.parse(process.env.SUPABASE_DB_URL || undefined),
};

export function getSupabaseConfigHealth() {
  const url = new URL(supabaseConfig.url);
  const localHosts = new Set(['localhost', '127.0.0.1', '::1']);
  const databaseUrl = supabaseConfig.databaseUrl ? new URL(supabaseConfig.databaseUrl) : undefined;
  const authLooksHosted = !localHosts.has(url.hostname);
  const dbLooksLocal = databaseUrl ? localHosts.has(databaseUrl.hostname) : false;
  return {
    supabaseHost: url.host,
    supabaseUrlPath: url.pathname || '/',
    supabaseUrlIsLocal: localHosts.has(url.hostname),
    hasAnonKey: Boolean(supabaseConfig.anonKey),
    hasServiceRoleKey: Boolean(supabaseConfig.serviceRoleKey),
    hasDbUrl: Boolean(supabaseConfig.databaseUrl),
    authHost: url.host,
    dbHost: databaseUrl?.host ?? 'not-configured',
    authLooksHosted,
    dbLooksLocal,
    possibleEnvMismatch: Boolean(databaseUrl && authLooksHosted !== !dbLooksLocal),
  };
}

export function logSupabaseConfigDiagnostics(): void {
  const health = getSupabaseConfigHealth();
  console.info(`[SupabaseConfig] urlHost=${health.supabaseHost}`);
  console.info(`[SupabaseConfig] urlPath=${health.supabaseUrlPath}`);
  console.info(`[SupabaseConfig] urlIsLocal=${health.supabaseUrlIsLocal}`);
  console.info(`[SupabaseConfig] hasAnonKey=${health.hasAnonKey}`);
  console.info(`[SupabaseConfig] hasServiceRoleKey=${health.hasServiceRoleKey}`);
  console.info(`[SupabaseConfig] hasDbUrl=${health.hasDbUrl}`);
  console.info(`[SupabaseConfig] authHost=${health.authHost}`);
  console.info(`[SupabaseConfig] dbHost=${health.dbHost}`);
  console.info(`[SupabaseConfig] authLooksHosted=${health.authLooksHosted}`);
  console.info(`[SupabaseConfig] dbLooksLocal=${health.dbLooksLocal}`);
  console.info(`[SupabaseConfig] possibleEnvMismatch=${health.possibleEnvMismatch}`);
  if (health.possibleEnvMismatch) {
    console.warn('SUPABASE_URL and SUPABASE_DB_URL appear to target different environments. Auth users may not exist in the profile database.');
  }
}

export function requireSupabaseDatabaseUrl(): string {
  if (!supabaseConfig.databaseUrl) throw new Error('SUPABASE_DB_URL is required');
  return supabaseConfig.databaseUrl;
}
