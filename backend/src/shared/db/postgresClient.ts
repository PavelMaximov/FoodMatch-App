import { AsyncLocalStorage } from 'async_hooks';
import { PoolClient, Pool, QueryResult, QueryResultRow } from 'pg';
import { requireSupabaseDatabaseUrl } from '../../config/supabase';

let pool: Pool | undefined;
const transaction = new AsyncLocalStorage<PoolClient>();

export function getPostgresPool(): Pool {
  pool ??= new Pool({ connectionString: requireSupabaseDatabaseUrl(), max: 10 });
  return pool;
}

export function queryPostgres<T extends QueryResultRow>(text: string, values: readonly unknown[] = []): Promise<QueryResult<T>> {
  return (transaction.getStore() ?? getPostgresPool()).query<T>(text, [...values]);
}

export async function closePostgresPool(): Promise<void> {
  await pool?.end();
  pool = undefined;
}

export async function withPostgresAdvisoryLock<T>(
  key: string,
  task: (query: typeof queryPostgres) => Promise<T>,
  pool: Pick<Pool, 'connect'> = getPostgresPool(),
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('begin');
    await client.query('select pg_advisory_xact_lock(hashtext($1))', [key]);
    const result = await task((text, values = []) => client.query(text, [...values]));
    await client.query('commit');
    return result;
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
}


/** Nested domain calls share one connection and roll back as a unit. */
export async function withPostgresTransaction<T>(task: () => Promise<T>): Promise<T> {
  if (transaction.getStore()) return task();
  const client = await getPostgresPool().connect();
  try {
    await client.query('begin');
    const result = await transaction.run(client, task);
    await client.query('commit');
    return result;
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally { client.release(); }
}
