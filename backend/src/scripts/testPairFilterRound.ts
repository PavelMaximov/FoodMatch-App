import assert from 'node:assert/strict';
import { supabaseConfig } from '../config/supabase';
import { getPostgresPool } from '../shared/db/postgresClient';
import { domainRepositories as repos } from '../infrastructure/repositories/domainRepositories';
import { CoupleService } from '../modules/couples/services/coupleService';

async function main() {
  supabaseConfig.databaseUrl = 'postgres://test:test@127.0.0.1/test';
  const pool = getPostgresPool();
  const original = pool.connect;
  (pool as any).connect = async () => ({
    query: async () => ({ rows: [] }),
    release() {},
  });
  try {
    const session: any = {
      id: 'pair',
      memberIds: ['a', 'b'],
      preparedDeckDishIds: ['old'],
      preparedDeckMeta: { status: 'ready' },
      pairLifecycleState: { status: 'active', generation: 1 },
    };
    const states: any[] = ['a', 'b'].map((userId) => ({
      userId,
      filters: {},
      confirmed: true,
      confirmedAt: new Date(),
    }));
    repos.coupleSessions.findActiveForUser = async () => session;
    repos.coupleSessions.findById = async () => session;
    repos.coupleSessions.listFilterStates = async () => states;
    repos.coupleSessions.update = async (_, patch) =>
      Object.assign(session, patch);
    repos.coupleSessions.upsertFilterState = async (_, state) => {
      Object.assign(
        states.find((x) => x.userId === state.userId),
        state,
      );
    };
    const service = new CoupleService();
    await service.updateMyFilterState('a', { cuisines: ['italian'] });
    assert.equal(states[1].confirmed, false);
    assert.equal(session.pairLifecycleState.generation, 2);
    assert.deepEqual(session.preparedDeckDishIds, []);
    assert.equal(
      (await service.confirmMyFilterState('a')).bothConfirmed,
      false,
    );
    await service.commitFilterChange('a');
    await service.updateMyFilterState('b', { cuisines: ['french'] });
    assert.equal(states[0].confirmed, true);
    assert.equal((await service.confirmMyFilterState('b')).bothConfirmed, true);
    await service.commitFilterChange('a');
    assert.equal(states[1].confirmed, true);
    assert.equal(session.pairLifecycleState.generation, 2);
    console.log(
      'PASS changed filters invalidate old confirmation; partner confirms same round; commit retry preserves consent',
    );
  } finally {
    pool.connect = original;
    await pool.end();
  }
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
