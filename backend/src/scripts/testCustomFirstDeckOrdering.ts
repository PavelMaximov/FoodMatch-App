import assert from 'node:assert/strict';
import { supabaseConfig } from '../config/supabase';
import { getPostgresPool } from '../shared/db/postgresClient';
import { domainRepositories as repos } from '../infrastructure/repositories/domainRepositories';
import { postgresDishes } from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { SoloDeckService } from '../modules/solo-swipes/services/soloDeckService';
import { CoupleDeckService } from '../modules/couples/services/coupleDeckService';

const dish = (
  id: string,
  custom = false,
  extra: Record<string, unknown> = {},
): any => ({
  id,
  _id: id,
  name: id,
  status: 'approved',
  visibility: custom ? 'private' : 'public',
  isCustom: custom,
  sourceType: custom ? 'custom' : 'catalog',
  createdBy: custom ? 'a' : null,
  dishRegister: custom ? 'unknown' : 'everyday',
  cuisine: custom ? 'japanese' : 'italian',
  diet: [],
  mood: [],
  ingredients: ['tomato'],
  season: [],
  source: [],
  popular: false,
  ...extra,
});
async function main() {
  supabaseConfig.databaseUrl = 'postgres://test:test@127.0.0.1/test';
  const pool = getPostgresPool();
  const connect = pool.connect;
  (pool as any).connect = async () => ({
    query: async () => ({ rows: [] }),
    release() {},
  });
  try {
    let catalog = [
      dish('public'),
      dish('owned', true),
      dish('foreign', true, { createdBy: 'other' }),
      dish('blocked', true, { ingredients: ['peanut'] }),
    ];
    postgresDishes.listLightweight = async () => catalog;
    repos.soloSessions.findResumable = async () => null;
    repos.coupleSessions.findActiveForUser = async () => null;
    const solo = new SoloDeckService();
    const filters = solo.normalizeFilter({
      dishRegisters: ['everyday'],
      cuisines: ['italian'],
      includeCustomDishesFirst: true,
      exclusions: ['no_nuts'],
    });
    const deck = await solo.buildDeck('a', filters);
    assert.equal(deck.dishes[0].id, 'owned');
    assert(!deck.dishes.some((d) => d.id === 'blocked'));
    assert.equal(deck.dishes.filter((d) => d.id === 'owned').length, 1);
    const excluded = await solo.buildDeck('a', filters, new Set(['owned']));
    assert(!excluded.dishes.some((d) => d.id === 'owned'));

    catalog = [
      ...Array.from({ length: 35 }, (_, i) => dish(`custom-${i}`, true)),
      ...Array.from({ length: 35 }, (_, i) => dish(`public-${i}`)),
    ];
    const session: any = {
      id: 'pair',
      memberIds: ['a', 'b'],
      status: 'active',
      preparedDeckGeneration: 0,
      preparedDeckDishIds: [],
      preparedDeckMeta: { status: 'idle' },
    };
    repos.coupleSessions.findActiveForUser = async () => session;
    repos.coupleSessions.findById = async () => session;
    repos.coupleSessions.listFilterStates = async () =>
      ['a', 'b'].map((userId) => ({
        userId,
        filters: {
          dishRegisters: ['everyday'],
          cuisines: ['italian'],
          includeCustomDishesFirst: userId === 'a',
        },
        confirmed: true,
        confirmedAt: new Date(),
      }));
    repos.coupleSessions.update = async (_id, patch) => {
      Object.assign(session, patch);
      return session;
    };
    const pair = await new CoupleDeckService().prepareDeckForActiveSession('a');
    assert.equal(
      pair.dishes.length,
      30,
      'custom prefix must not overflow the deck limit',
    );
    assert.equal(session.preparedDeckDishIds.length, 30);
    assert(
      pair.dishes.every((d: { id: string } | null) =>
        d?.id.startsWith('custom-'),
      ),
    );
    assert.equal(pair.meta.recommendationMeta.customIncludedCount, 30);
    assert.equal(new Set(session.preparedDeckDishIds).size, 30);
    console.log(
      'PASS custom-first ordering, hard exclusions, replay exclusion, no duplicates and 30-card pair cap',
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
