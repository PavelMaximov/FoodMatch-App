import { AsyncLocalStorage } from 'async_hooks';
import { Pool, PoolClient, QueryResult, QueryResultRow } from 'pg';
import { requireSupabaseDatabaseUrl } from '../../config/supabase';

let pool: Pool | undefined;
const transaction = new AsyncLocalStorage<PoolClient>();

export function getPostgresPool(): Pool {
  pool ??= new Pool({
    connectionString: requireSupabaseDatabaseUrl(),
    max: 10,
  });
  return pool;
}

export function queryPostgres<T extends QueryResultRow>(
  text: string,
  values: readonly unknown[] = [],
): Promise<QueryResult<T>> {
  return (transaction.getStore() ?? getPostgresPool()).query<T>(text, [
    ...values,
  ]);
}

export async function closePostgresPool(): Promise<void> {
  await pool?.end();
  pool = undefined;
}

export async function withPostgresAdvisoryLock<T>(
  key: string,
  task: (query: typeof queryPostgres) => Promise<T>,
  connectionPool?: Pick<Pool, 'connect'>,
): Promise<T> {
  return withPostgresTransaction(async () => {
    await queryPostgres('select pg_advisory_xact_lock(hashtext($1))', [key]);
    return task(queryPostgres);
  }, connectionPool);
}

/** Nested domain calls share one connection and roll back as a unit. */
export async function withPostgresTransaction<T>(
  task: () => Promise<T>,
  connectionPool?: Pick<Pool, 'connect'>,
): Promise<T> {
  if (transaction.getStore()) return task();
  const client = await (connectionPool ?? getPostgresPool()).connect();
  let discard: Error | undefined;
  try {
    await client.query('begin');
    const result = await transaction.run(client, task);
    await client.query('commit');
    return result;
  } catch (error) {
    try {
      await client.query('rollback');
    } catch (rollbackError) {
      // Preserve the operation failure and never reuse a broken connection.
      discard =
        rollbackError instanceof Error
          ? rollbackError
          : new Error('Rollback failed');
    }
    throw error;
  } finally {
    client.release(discard);
  }
}
