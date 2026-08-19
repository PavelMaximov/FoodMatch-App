import { z } from 'zod';

const optionalUrl = z.string().url().optional();

export const supabaseConfig = {
  url: optionalUrl.parse(process.env.SUPABASE_URL || undefined),
  anonKey: process.env.SUPABASE_ANON_KEY || undefined,
  serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || undefined,
  databaseUrl: optionalUrl.parse(process.env.SUPABASE_DB_URL || undefined),
};

export function requireSupabaseDatabaseUrl(): string {
  if (!supabaseConfig.databaseUrl) throw new Error('SUPABASE_DB_URL is required');
  return supabaseConfig.databaseUrl;
}
