import assert from 'node:assert/strict';
import { supabaseConfig } from '../config/supabase';
import { getPostgresPool } from '../shared/db/postgresClient';
import { domainRepositories as repos } from '../infrastructure/repositories/domainRepositories';
import { postgresDishes } from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import {
  CoupleDeckService,
  buildEffectiveFilters,
  createFiltersHash,
} from '../modules/couples/services/coupleDeckService';

async function main() {
  supabaseConfig.databaseUrl = 'postgres://test:test@127.0.0.1/test';
  const pool = getPostgresPool();
  const connect = pool.connect;
  let transactions = 0;
  (pool as any).connect = async () => {
    transactions++;
    return { query: async () => ({ rows: [] }), release() {} };
  };
  try {
    const session: any = {
      id: 'pair',
      memberIds: ['a', 'b'],
      status: 'active',
      preparedDeckGeneration: 1,
      preparedDeckDishIds: ['dish'],
      preparedDeckMeta: { status: 'ready' },
    };
    const choices = session.memberIds.map((userId: string) => ({
      userId,
      filters: {},
      confirmed: true,
      confirmedAt: new Date(),
    }));
    session.preparedDeckFiltersHash = createFiltersHash(
      buildEffectiveFilters({ ...session, choices }, 'a'),
    );
    repos.coupleSessions.findActiveForUser = async () => session;
    repos.coupleSessions.listFilterStates = async () => choices;
    let writes = 0,
      catalogLoads = 0,
      hydrations = 0;
    repos.coupleSessions.update = async () => {
      writes++;
      return session;
    };
    postgresDishes.listLightweight = async () => {
      catalogLoads++;
      return [];
    };
    let release!: () => void;
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    postgresDishes.getLightweightByIds = async (ids) => {
      hydrations++;
      assert.deepEqual(ids, ['dish']);
      await gate;
      return [{ id: 'dish', _id: 'dish', name: 'Dish' }] as any;
    };
    const service = new CoupleDeckService();
    const first = service.prepareDeckForActiveSession('a');
    const second = service.prepareDeckForActiveSession('b');
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(hydrations, 1);
    assert.equal(transactions, 1);
    release();
    const [one, two] = await Promise.all([first, second]);
    assert.deepEqual(one, two);
    assert.equal(writes, 0);
    assert.equal(catalogLoads, 0);
    await service.prepareDeckForActiveSession('a');
    assert.equal(hydrations, 2);
    assert.equal(writes, 0);
    choices[1].confirmed = false;
    await assert.rejects(
      service.prepareDeckForActiveSession('a'),
      (e: any) => e.code === 'FILTERS_NOT_READY',
    );
    choices[1].confirmed = true;
    await service.prepareDeckForActiveSession('a');
    assert.equal(hydrations, 3, 'failed flight must not poison the next retry');
    console.log(
      'PASS paired deck shared in-flight result, persisted reuse, confirmation gate and retry after failure',
    );
  } finally {
    pool.connect = connect;
    await pool.end();
  }
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
