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

export async function withPostgresAdvisoryLock<T>(key: string, task: () => Promise<T>): Promise<T> {
  const client = await getPostgresPool().connect();
  try {
    await client.query('begin');
    await client.query('select pg_advisory_xact_lock(hashtext($1))', [key]);
    const result = await task();
    await client.query('commit');
    return result;
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
}
