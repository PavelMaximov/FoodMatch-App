import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { supabaseConfig } from '../../config/supabase';

let client: SupabaseClient | undefined;

/** Backend-only client. Its key must never be bundled into Flutter. */
export function getSupabaseAdminClient(): SupabaseClient {
  if (!supabaseConfig.url || !supabaseConfig.serviceRoleKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required');
  }
  client ??= createClient(supabaseConfig.url, supabaseConfig.serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return client;
}
