import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionRecord } from '../../../domain/repositories/types';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { queryPostgres } from '../../../shared/db/postgresClient';

export type PairScope = { sessionId?: string; generation?: number };

// All membership transitions acquire user locks in the same order, before rows.
export async function lockSessionUsers(users: string[]) {
  for (const user of [...new Set(users)].sort()) {
    await queryPostgres('select pg_advisory_xact_lock(hashtext($1))', [`session-user:${user}`]);
  }
}

export function assertPairScope(session: CoupleSessionRecord, scope: PairScope = {}) {
  if (scope.sessionId && scope.sessionId !== session.id)
    throw new AppError('This pair session has changed. Refresh and try again.', 409, 'PAIR_SESSION_CHANGED');
  if (scope.generation !== undefined && scope.generation !== Number(session.pairLifecycleState.generation ?? 0))
    throw new AppError('Your partner changed the session. Refresh the filters and try again.', 409, 'PAIR_FILTER_ROUND_CHANGED');
}

/** Call inside a transaction. Never switch to a replacement session after waiting for a row lock. */
export async function lockActivePair(userId: string, scope: PairScope = {}) {
  const before = await domainRepositories.coupleSessions.findActiveForUser(userId);
  if (!before) throw new AppError('This pair session is no longer active.', 404, 'PAIR_SESSION_INACTIVE');
  assertPairScope(before, scope);
  await queryPostgres('select id from couple_sessions where id=$1 for update', [before.id]);
  const after = await domainRepositories.coupleSessions.findActiveForUser(userId);
  if (!after || after.id !== before.id)
    throw new AppError('This pair session has changed. Refresh and try again.', 409, 'PAIR_SESSION_CHANGED');
  assertPairScope(after, scope);
  return after;
}
