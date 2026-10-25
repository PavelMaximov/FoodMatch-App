import 'dotenv/config';
import { connect } from './supabaseImportUtils';

const privateCatalogTables = ['dish_tags','dish_sections','dish_components','dish_component_measurements','dish_instructions','ingredients'];
const tables = ['profiles','dishes','user_saved_dishes','solo_swipe_sessions','couple_sessions','pair_filter_states','swipes','matches','couple_invitations','filter_presets','user_subscriptions','rewarded_feature_grants','shared_shopping_list_items', ...privateCatalogTables];
async function main() {
  const db = await connect();
  try {
    const enabled = await db.query<{ relname: string }>(`select relname from pg_class where relnamespace='public'::regnamespace and relrowsecurity and relname=any($1)`, [tables]);
    const policies = await db.query<{ tablename: string }>(`select distinct tablename from pg_policies where schemaname='public' and tablename=any($1)`, [tables]);
    const missingRls = tables.filter((table) => !enabled.rows.some((row) => row.relname === table));
    const missingPolicies = tables.filter((table) => !privateCatalogTables.includes(table) && !policies.rows.some((row) => row.tablename === table));
    if (missingRls.length || missingPolicies.length) throw new Error(`RLS readiness failed. Disabled: ${missingRls.join(', ') || 'none'}; without policies: ${missingPolicies.join(', ') || 'none'}`);
    const grants = await db.query<{table_name:string; grantee:string; privilege_type:string}>(
      `select table_name,grantee,privilege_type from information_schema.table_privileges
       where table_schema='public' and grantee in ('PUBLIC','anon','authenticated')
       and (table_name=any($1) or (table_name='dishes' and privilege_type <> 'SELECT'))`, [privateCatalogTables]);
    const columnGrants = await db.query(`select 1 from information_schema.column_privileges
      where table_schema='public' and table_name='dishes'
      and grantee in ('PUBLIC','anon','authenticated') and privilege_type <> 'SELECT'`);
    if (grants.rows.length || columnGrants.rows.length) throw new Error('Unsafe catalog client grants remain');
    console.log(`RLS check passed: ${tables.length} tables enabled; private catalog denied by default`);
  } finally { await db.end(); }
}
main().catch((error) => { console.error(error instanceof Error ? error.message : error); process.exitCode = 1; });
