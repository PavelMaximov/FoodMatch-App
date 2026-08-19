import { Pool, QueryResult, QueryResultRow } from 'pg';
import { requireSupabaseDatabaseUrl } from '../../config/supabase';

let pool: Pool | undefined;

export function getPostgresPool(): Pool {
  pool ??= new Pool({ connectionString: requireSupabaseDatabaseUrl(), max: 10 });
  return pool;
}

export function queryPostgres<T extends QueryResultRow>(text: string, values: readonly unknown[] = []): Promise<QueryResult<T>> {
  return getPostgresPool().query<T>(text, [...values]);
}

export async function closePostgresPool(): Promise<void> {
  await pool?.end();
  pool = undefined;
}
