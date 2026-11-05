import assert from 'node:assert/strict';
import { SessionResumeService } from '../modules/swipes/services/sessionResumeService';
import { MatchQueryService } from '../modules/matches/services/matchQueryService';
import { queryPostgres } from '../shared/db/postgresClient';
import { domainRepositories as repos } from '../infrastructure/repositories/domainRepositories';
import { postgresDishes } from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';

async function main() {
  let latest: Record<string, unknown> | null = null;
  const query = (async (sql: string, values: readonly unknown[]) => {
    assert.deepEqual(values, ['owner']);
    assert(sql.includes('s.user_id=$1') && sql.includes('$1=any(c.member_ids)'));
    assert(sql.includes('order by created_at desc'));
    return { rows: latest ? [latest] : [], rowCount: latest ? 1 : 0 };
  }) as typeof queryPostgres;
  const resume = new SessionResumeService(query);
  assert.deepEqual(await resume.getForUser('owner'), { session: null });
  for (const [mode, status, count, pending, action] of [
    ['paired', 'closed', 2, false, 'new'],
    ['solo', 'closed', 1, false, 'new'],
    ['solo', 'active', 1, false, 'resume'],
    ['solo', 'completed', 1, false, 'resume'],
    ['paired', 'active', 2, false, 'resume'],
    ['paired', 'active', 1, false, 'connect_pair'],
    ['paired', 'active', 1, true, 'resume'],
  ] as const) {
    latest = { id: 'last-session', mode, status, member_count: count, pending_continuation: pending };
    assert.equal((await resume.getForUser('owner')).session?.action, action);
  }

  const oldRows: any[] = [{ id: 'historic', dishId: 'dish', mode: 'paired', coupleSessionId: 'old-pair', createdAt: new Date() }];
  const newRows: any[] = [];
  let active: any = { id: 'new-pair', status: 'active', memberIds: ['owner', 'same-partner'] };
  repos.coupleSessions.findActiveForUser = async () => active;
  repos.matches.listForUser = async () => { throw Error('Current Pair must not read cross-session history'); };
  repos.matches.listForCouple = async (id) => {
    assert.equal(id, 'new-pair');
    return newRows;
  };
  postgresDishes.getByIds = async () => [{ id: 'dish', _id: 'dish', name: 'Dish', status: 'approved', visibility: 'public' }] as any;
  const matches = new MatchQueryService();
  assert.deepEqual(await matches.getMyMatches('owner', 'paired'), []);
  assert.deepEqual(await matches.getMyMatches('owner'), []);
  assert.equal(oldRows.length, 1, 'History is retained');
  newRows.push({ ...oldRows[0], id: 'new-match', coupleSessionId: 'new-pair' });
  const current = await matches.getMyMatches('owner', 'paired', { scope: 'current', sessionId: 'new-pair' });
  assert.equal(current.length, 1);
  assert.equal(current[0]!.id, 'new-match');
  await assert.rejects(matches.getMyMatches('owner', 'paired', { sessionId: 'old-pair' }),
    (error: any) => error.code === 'PAIR_SESSION_CHANGED');
  active = null;
  assert.deepEqual(await matches.getMyMatches('owner', 'paired'), []);
  console.log('PASS authoritative resume actions; new same-partner matches exclude history and stale session IDs');
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
