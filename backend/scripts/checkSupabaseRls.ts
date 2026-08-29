import 'dotenv/config';
import { connect } from './supabaseImportUtils';

const tables = ['profiles','dishes','user_saved_dishes','solo_swipe_sessions','couple_sessions','pair_filter_states','swipes','matches','couple_invitations','filter_presets'];
async function main() {
  const db = await connect();
  try {
    const enabled = await db.query<{ relname: string }>(`select relname from pg_class where relnamespace='public'::regnamespace and relrowsecurity and relname=any($1)`, [tables]);
    const policies = await db.query<{ tablename: string }>(`select distinct tablename from pg_policies where schemaname='public' and tablename=any($1)`, [tables]);
    const missingRls = tables.filter((table) => !enabled.rows.some((row) => row.relname === table));
    const missingPolicies = tables.filter((table) => !policies.rows.some((row) => row.tablename === table));
    if (missingRls.length || missingPolicies.length) throw new Error(`RLS readiness failed. Disabled: ${missingRls.join(', ') || 'none'}; without policies: ${missingPolicies.join(', ') || 'none'}`);
    console.log(`RLS check passed: ${tables.length} tables enabled with explicit policies`);
  } finally { await db.end(); }
}
main().catch((error) => { console.error(error instanceof Error ? error.message : error); process.exitCode = 1; });
