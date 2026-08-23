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
  return {
    supabaseHost: url.host,
    supabaseUrlPath: url.pathname || '/',
    supabaseUrlIsLocal: localHosts.has(url.hostname),
    hasAnonKey: Boolean(supabaseConfig.anonKey),
    hasServiceRoleKey: Boolean(supabaseConfig.serviceRoleKey),
    hasDbUrl: Boolean(supabaseConfig.databaseUrl),
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
}

export function requireSupabaseDatabaseUrl(): string {
  if (!supabaseConfig.databaseUrl) throw new Error('SUPABASE_DB_URL is required');
  return supabaseConfig.databaseUrl;
}
