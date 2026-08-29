import { queryPostgres, closePostgresPool } from '../shared/db/postgresClient';

const api = (process.env.API_BASE_URL || `http://127.0.0.1:${process.env.PORT || 4000}`).replace(/\/$/, '');
async function request(path: string, token?: string) {
  const response = await fetch(`${api}${path}`, { headers: token ? { authorization: `Bearer ${token}` } : undefined });
  if (!response.ok) throw new Error(`${path} returned HTTP ${response.status}`);
  return response.json();
}
async function main() {
  const tables = await queryPostgres<{ table_name: string }>(`select table_name from information_schema.tables where table_schema='public'`);
  for (const required of ['profiles','dishes','dish_components','dish_instructions','user_saved_dishes','solo_swipe_sessions','couple_sessions','swipes','matches']) {
    if (!tables.rows.some((row) => row.table_name === required)) throw new Error(`Required table missing: ${required}`);
  }
  const dish = await queryPostgres<{ id: string }>(`select d.id from dishes d where exists(select 1 from dish_instructions i where i.dish_id=d.id) and exists(select 1 from dish_components c where c.dish_id=d.id) limit 1`);
  if (!dish.rowCount) throw new Error('No dish with ordered steps and ingredients is ready');
  console.log('PASS PostgreSQL schema and catalog readiness');
  await request('/api/dishes?limit=all');
  await request(`/api/dishes/${dish.rows[0].id}`);
  console.log('PASS public dish endpoints');
  const token = process.env.QA_USER_TOKEN || process.env.QA_USER_A_TOKEN;
  if (token) {
    await request('/api/auth/me', token); await request('/api/users/saved-dishes', token);
    console.log('PASS authenticated identity and saved dishes endpoints');
  } else console.warn('SKIP authenticated endpoint checks (set QA_USER_TOKEN)');
  if (process.env.QA_USER_A_TOKEN && process.env.QA_USER_B_TOKEN) console.warn('INFO Pair/Solo mutation checks require disposable QA data and remain manual; both tokens are configured.');
  else console.warn('SKIP Pair flow checks (set QA_USER_A_TOKEN and QA_USER_B_TOKEN)');
}
main().catch((error) => { console.error('Production readiness FAILED:', error instanceof Error ? error.message : error); process.exitCode = 1; }).finally(closePostgresPool);
