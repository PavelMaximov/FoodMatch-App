import assert from 'node:assert/strict';
import { supabaseConfig } from '../config/supabase';
import { postgresDishes } from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { PostgresSoloSessionRepository } from '../infrastructure/postgres/repositories/PostgresSoloSessionRepository';
import { domainRepositories as repos } from '../infrastructure/repositories/domainRepositories';
import {
  buildEffectiveFilters,
  createFiltersHash,
} from '../modules/couples/domain/pairDeckPolicy';
import { MatchService } from '../modules/matches/services/matchService';
import { SoloDeckService } from '../modules/solo-swipes/services/soloDeckService';
import { SwipeService } from '../modules/swipes/services/swipeService';
import {
  getPostgresPool,
  queryPostgres,
  withPostgresAdvisoryLock,
  withPostgresTransaction,
} from '../shared/db/postgresClient';

async function main() {
  supabaseConfig.databaseUrl = 'postgres://test:test@127.0.0.1/test';
  const pool = getPostgresPool();
  const originalConnect = pool.connect;
  const sql: string[] = [];
  let connections = 0;
  let releases = 0;
  let rollbackFailure = false;
  let discarded: unknown;
  (pool as any).connect = async () => {
    connections++;
    return {
      query: async (text: string) => {
        sql.push(text);
        if (text === 'rollback' && rollbackFailure)
          throw new Error('connection lost');
        return {
          rows: text.startsWith('insert into solo_swipe_sessions')
            ? [{ id: 'replacement' }]
            : [],
          rowCount: 0,
        };
      },
      release: (error?: Error) => {
        releases++;
        discarded = error;
      },
    };
  };
  try {
    await withPostgresTransaction(async () => {
      await withPostgresAdvisoryLock('deck', async (query) => {
        await query('explicit');
        await queryPostgres('ambient');
        await withPostgresTransaction(async () => {
          await queryPostgres('nested');
        });
      });
    });
    assert.deepEqual(sql, [
      'begin',
      'select pg_advisory_xact_lock(hashtext($1))',
      'explicit',
      'ambient',
      'nested',
      'commit',
    ]);
    assert.equal(connections, 1);
    assert.equal(releases, 1);
    sql.length = 0;
    const failure = new Error('domain failed');
    rollbackFailure = true;
    await assert.rejects(
      withPostgresTransaction(async () => {
        throw failure;
      }),
      (error) => error === failure,
    );
    assert(discarded instanceof Error);
    rollbackFailure = false;
    sql.length = 0;
    const before = connections;
    await assert.rejects(
      withPostgresTransaction(async () => {
        const replacement =
          await new PostgresSoloSessionRepository().replaceActive({
            userId: 'user',
            deckDishIds: [],
            filters: {},
          });
        assert.equal(replacement.id, 'replacement');
        throw failure;
      }),
      (error) => error === failure,
    );
    assert.equal(connections, before + 1);
    assert.equal(sql.filter((q) => q === 'begin').length, 1);
    assert(!sql.includes('commit'));
    assert.equal(sql.at(-1), 'rollback');
    console.log(
      'PASS ambient advisory lock, nested replacement rollback and broken-connection disposal',
    );

    const session: any = {
      id: 'pair',
      status: 'active',
      memberIds: ['user', 'partner'],
      preparedDeckDishIds: ['dish'],
    };
    repos.coupleSessions.findActiveForUser = async () => session;
    postgresDishes.getByPublicId = async () =>
      ({
        id: 'dish',
        _id: 'dish',
        name: 'Dish',
        status: 'approved',
        visibility: 'public',
      }) as any;
    let count = 0;
    let writes = 0;
    let storedDirection = 'like';
    repos.matches.listForCouple = async () =>
      Array.from({ length: count }, (_, i) => ({ id: `m${i}` })) as any;
    repos.swipes.createOnce = async () => {
      writes++;
      return {
        swipe: { id: 'swipe', direction: storedDirection },
        created: writes === 1,
      } as any;
    };
    repos.swipes.countLikes = async () => 2;
    repos.matches.createOnce = async () => {
      const created = count === 0;
      count = 1;
      return { match: { id: 'match' }, created } as any;
    };
    const service = new SwipeService();
    sql.length = 0;
    const first = await service.createSwipe('user', 'dish', 'like', 'pair');
    assert.equal(first.badgeDelta, 1);
    assert.equal(first.matchCreated, true);
    assert.equal(first.coupleId, 'pair');
    assert.equal(first.dishId, 'dish');
    assert(
      sql.some(
        (q) => q.includes('couple_sessions') && q.includes('for update'),
      ),
    );
    assert.equal(sql.at(-1), 'commit');
    const replay = await service.createSwipe('user', 'dish', 'like', 'pair');
    assert.equal(replay.alreadySwiped, true);
    assert.equal(replay.badgeDelta, 0);
    assert.equal(replay.matchCreated, false);
    await assert.rejects(
      service.createSwipe('user', 'dish', 'like', 'old-pair'),
      (e: any) => e.code === 'SWIPE_SESSION_CHANGED',
    );
    const beforeWrites = writes;
    let lookups = 0;
    repos.coupleSessions.findActiveForUser = async () =>
      ++lookups === 1 ? session : { ...session, id: 'new-pair' };
    await assert.rejects(
      service.createSwipe('user', 'dish', 'like'),
      (e: any) => e.code === 'SWIPE_SESSION_CHANGED',
    );
    assert.equal(writes, beforeWrites);
    repos.coupleSessions.findActiveForUser = async () => session;
    storedDirection = 'dislike';
    await assert.rejects(
      service.createSwipe('user', 'dish', 'like'),
      (e: any) => e.code === 'SWIPE_CONFLICT',
    );
    storedDirection = 'like';
    repos.matches.createOnce = async () => {
      throw failure;
    };
    sql.length = 0;
    await assert.rejects(
      service.createSwipe('user', 'dish', 'like'),
      (error) => error === failure,
    );
    assert.equal(sql.at(-1), 'rollback');
    assert(!sql.includes('commit'));
    console.log(
      'PASS pair swipe DTO, replay, conflicting direction, session replacement and mutation rollback',
    );

    const rows: any[] = [
      {
        id: 'missing-match',
        dishId: 'missing',
        direction: 'dislike',
        mode: 'paired',
      },
      {
        id: 'existing-match',
        dishId: 'dish',
        direction: 'like',
        mode: 'paired',
      },
    ];
    postgresDishes.getByIds = async () =>
      [
        {
          id: 'dish',
          _id: 'dish',
          name: 'Dish',
          status: 'approved',
          visibility: 'public',
        },
      ] as any;
    repos.matches.listForUser = async () => rows;
    repos.matches.listForCouple = async () => rows;
    repos.swipes.listForUserSession = async () => rows;
    repos.soloSessions.findResumable = async () => null;
    const matches = await service.getMyMatches('user');
    assert.equal(matches.length, 1);
    assert.equal(matches[0]!.id, 'existing-match');
    assert.equal(matches[0]!.dish.id, 'dish');
    const history = await service.getMySwipeHistory('user');
    assert.equal(history.length, 1);
    assert.equal(history[0].id, 'existing-match');
    const coupleMatches = await new MatchService().listForCouple('pair');
    assert.equal(coupleMatches.length, 1);
    assert.equal(coupleMatches[0].id, 'existing-match');
    const recommendationHistory = await new SoloDeckService().loadUserHistory(
      'user',
    );
    assert.equal(recommendationHistory.length, 1);
    assert.equal(recommendationHistory[0].direction, 'like');
    repos.soloSessions.findByIdForUser = async () => null;
    await assert.rejects(
      service.getMyMatches('user', 'solo', {
        scope: 'current',
        sessionId: 'foreign',
      }),
      (e: any) => e.code === 'SOLO_SESSION_FORBIDDEN',
    );
    console.log(
      'PASS missing catalog rows preserve match, swipe and recommendation identity; Solo ownership retained',
    );

    const policyInput = {
      id: 'pair',
      memberIds: ['user', 'partner'],
      choices: [
        {
          userId: 'user',
          confirmed: true,
          filters: {
            cuisines: ['Italian'],
            exclusions: ['nuts'],
            maxCookTime: 40,
          },
        },
        {
          userId: 'partner',
          confirmed: true,
          filters: {
            cuisines: ['Thai'],
            exclusions: ['milk'],
            maxCookTime: 20,
          },
        },
      ],
    };
    const filters = buildEffectiveFilters(policyInput, 'user');
    assert.equal(filters.bothConfirmed, true);
    assert.equal(filters.usedCuisineUnionFallback, true);
    assert.deepEqual(filters.cuisines, ['italian', 'thai']);
    assert.deepEqual(filters.exclusions, ['milk', 'nuts']);
    assert.equal(filters.maxCookTime, 20);
    assert.equal(
      createFiltersHash(filters),
      createFiltersHash(
        buildEffectiveFilters(
          { ...policyInput, choices: [...policyInput.choices].reverse() },
          'user',
        ),
      ),
    );
    assert.notEqual(
      createFiltersHash(filters),
      createFiltersHash({ ...filters, sessionId: 'other' }),
    );
    console.log(
      'PASS extracted pair filter policy preserves hard filters, fallback and scoped deterministic hashing',
    );
  } finally {
    pool.connect = originalConnect;
    await pool.end();
  }
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
