import { lockActivePair, PairScope } from './pairSessionGuard';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionRecord } from '../../../domain/repositories/types';
import {
  CatalogDish as DishDocument,
  postgresDishes,
} from '../../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import {
  loadLightweightDishesInPostgresOrder,
  postgresDishId,
} from '../../../shared/db/dishIdMapping';
import {
  withPostgresAdvisoryLock,
  withPostgresTransaction,
} from '../../../shared/db/postgresClient';
import { toDishDto } from '../../dishes/dto/dishDto';
import { buildPairSharedRecommendedDeck } from '../../recommendations/deckRecommendationService';
import { logRecommendationMeta } from '../../recommendations/recommendationTypes';
import {
  buildEffectiveFilters,
  Choice,
  choiceFilters,
  createFiltersHash,
  customFirst,
  EffectiveDeckFilters,
  isCustom,
} from '../domain/pairDeckPolicy';
const MAX = 30;
const prepareFlights = new Map<string, Promise<any>>();
export class CoupleDeckService {
  async prepareDeckForActiveSession(userId: string) {
    const total = Date.now(),
      lookup = Date.now(),
      session = await this.require(userId);
    this.timing('active session lookup', Date.now() - lookup);
    const key = `${session.id}:${session.preparedDeckGeneration}`;
    const existing = prepareFlights.get(key);
    if (existing) return existing;
    const flight = withPostgresAdvisoryLock(
      `pair-deck:${key}:weighted_category_cuisine_v1`,
      () => this.computeDeck(userId, session.id),
    ).finally(() => prepareFlights.delete(key));
    prepareFlights.set(key, flight);
    const result = await flight;
    this.timing('total', Date.now() - total);
    return result;
  }
  private async computeDeck(userId: string, expectedSessionId: string) {
    const s = await lockActivePair(userId, { sessionId: expectedSessionId }),
      filterStarted = Date.now(),
      choices = await this.choices(s);
    this.timing('filter load', Date.now() - filterStarted);
    const filters = buildEffectiveFilters({ ...s, choices }, userId);
    if (!filters.bothConfirmed)
      throw new AppError(
        'Waiting for partner to finish filters',
        409,
        'FILTERS_NOT_READY',
        { bothConfirmed: false },
      );
    const hash = createFiltersHash(filters),
      meta = s.preparedDeckMeta as any;
    if (
      s.preparedDeckDishIds.length &&
      meta.status === 'ready' &&
      s.preparedDeckFiltersHash === hash
    ) {
      const hydration = Date.now(),
        dishes = await loadLightweightDishesInPostgresOrder(
          s.preparedDeckDishIds,
        );
      this.timing('response hydration', Date.now() - hydration);
      return this.response(s, dishes, filters);
    }
    const runtimeIds = new Map(s.memberIds.map((x) => [x, x]));
    const catalogStarted = Date.now(),
      all = (
        await Promise.all(
          s.memberIds.map((x) => postgresDishes.listLightweight(x)),
        )
      )
        .flat()
        .filter((d, i, a) => a.findIndex((x) => x.id === d.id) === i);
    this.timing('catalog lightweight load', Date.now() - catalogStarted);
    const scoringStarted = Date.now(),
      contexts = choices.map((c) => ({
        userId: c.userId,
        filters: choiceFilters(c),
        userHistory: [],
        recencyScores: new Map<string, number>(),
      }));
    const result = buildPairSharedRecommendedDeck({
      users: contexts,
      dishes: all,
      hardFilters: filters,
      excludedDishIds: new Set(),
      deckSize: MAX,
      customDishIds: new Set(all.filter(isCustom).map((d) => d._id.toString())),
    });
    this.timing('scoring', Date.now() - scoringStarted);
    const prefix = filters.includeCustomDishesFirst
        ? customFirst(all, filters, choices, runtimeIds).slice(0, MAX)
        : [],
      seen = new Set(prefix.map((d) => d._id.toString())),
      tail = result.dishes
        .filter((d) => !seen.has(d._id.toString()))
        .slice(0, MAX - prefix.length),
      final = [...prefix, ...tail],
      ids = await Promise.all(final.map(postgresDishId)),
      recommendationMeta = {
        ...result.meta,
        finalCount: final.length,
        customIncludedCount: prefix.length,
        filtersHash: hash,
        bothUsersConfirmed: true,
      },
      writeStarted = Date.now();
    await domainRepositories.coupleSessions.update(s.id, {
      pairLifecycleState: { ...s.pairLifecycleState, status: 'active' },
      preparedDeckDishIds: ids,
      preparedDeckFiltersHash: hash,
      restartState: { requestedBy: [], status: 'idle', generation: Number(s.restartState?.generation ?? 0) },
      preparedDeckGeneration: s.preparedDeckGeneration + 1,
      preparedDeckMeta: {
        status: 'ready',
        totalCatalogCount: all.length,
        candidateCount: result.meta.candidateCount,
        finalCount: final.length,
        generatedAt: new Date(),
        reason: result.meta.expansionReason ?? null,
        recommendationMeta,
      },
    });
    this.timing('prepared deck write', Date.now() - writeStarted);
    logRecommendationMeta(recommendationMeta, { sessionId: s.id });
    this.timing('response hydration', 0);
    return this.response(
      (await domainRepositories.coupleSessions.findById(s.id))!,
      final,
      filters,
    );
  }
  async getDeckForActiveSession(userId: string) {
    const total = Date.now(),
      idsStarted = Date.now(),
      s = await this.require(userId),
      filters = buildEffectiveFilters(
        { ...s, choices: await this.choices(s) },
        userId,
      ),
      hash = createFiltersHash(filters);
    this.loadTiming('prepared ids load', Date.now() - idsStarted);
    if (!s.preparedDeckDishIds.length || s.preparedDeckFiltersHash !== hash) {
      this.loadTiming('total', Date.now() - total);
      return this.empty(filters, hash);
    }
    const hydration = Date.now(),
      dishes = await loadLightweightDishesInPostgresOrder(
        s.preparedDeckDishIds,
      );
    this.loadTiming('dish hydration', Date.now() - hydration);
    this.loadTiming('total', Date.now() - total);
    return this.response(s, dishes, filters);
  }
  async resetDeckForActiveSession(userId: string) {
    const s = await this.require(userId);
    await domainRepositories.coupleSessions.update(s.id, {
      preparedDeckDishIds: [],
      preparedDeckFiltersHash: null,
      preparedDeckMeta: { status: 'idle' },
    });
    const f = buildEffectiveFilters(
      { ...s, choices: await this.choices(s) },
      userId,
    );
    return this.empty(f, createFiltersHash(f));
  }
  async requestDeckRestart(userId: string, scope: PairScope = {}) {
    return withPostgresTransaction(async () => {
      const s = await lockActivePair(userId, scope);
      const old = s.restartState as any;
      if (old.status === 'ready') return this.restartResponse(s);
      const requested = [...new Set([...(old.requestedBy ?? []), userId])];
      const ready = s.memberIds.length === 2 && s.memberIds.every((id) => requested.includes(id));
      const state = {
        requestedBy: requested,
        status: ready ? 'ready' : 'waiting',
        generation: Number(old.generation ?? 0) + (ready ? 1 : 0),
        updatedAt: new Date(),
      };
      if (ready) await domainRepositories.coupleSessions.clearFilterStates(s.id);
      const updated = await domainRepositories.coupleSessions.update(s.id, {
        restartState: state,
        ...(ready ? {
          preparedDeckDishIds: [], preparedDeckFiltersHash: null, preparedDeckMeta: { status: 'idle' },
          pairLifecycleState: { ...s.pairLifecycleState, generation: Number(s.pairLifecycleState.generation ?? 0) + 1 },
        } : {}),
      });
      return this.restartResponse(updated!);
    });
  }
  async getDeckRestartStatus(userId: string) {
    // Polling is read-only. Both partners must observe the same durable decision.
    return this.restartResponse(await this.require(userId));
  }
  private restartResponse(s: CoupleSessionRecord) {
    const state = s.restartState as any;
    return {
      status: state.status ?? 'idle', requestedBy: state.requestedBy ?? [],
      requiredUserIds: s.memberIds, allRequested: state.status === 'ready',
      generation: Number(state.generation ?? 0), sessionId: s.id,
      filterGeneration: Number(s.pairLifecycleState.generation ?? 0),
    };
  }
  private async choices(s: CoupleSessionRecord): Promise<Choice[]> {
    return (await domainRepositories.coupleSessions.listFilterStates(s.id)).map(
      (x) => ({ userId: x.userId, filters: x.filters, confirmed: x.confirmed }),
    );
  }
  private async require(u: string) {
    const s = await domainRepositories.coupleSessions.findActiveForUser(u);
    if (!s)
      throw new AppError(
        'This pair session is no longer active.',
        404,
        'PAIR_SESSION_INACTIVE',
      );
    return s;
  }
  private timing(label: string, ms: number) {
    if (process.env.NODE_ENV !== 'production')
      console.info(`[PairDeckPrepare] ${label} ms=${ms}`);
  }
  private loadTiming(label: string, ms: number) {
    if (process.env.NODE_ENV !== 'production')
      console.info(`[PairDeckLoad] ${label} ms=${ms}`);
  }
  private response(
    s: CoupleSessionRecord,
    dishes: DishDocument[],
    f: EffectiveDeckFilters,
  ) {
    const m = s.preparedDeckMeta as any;
    return {
      status: m.status ?? 'ready',
      dishes: dishes.map(toDishDto).filter(Boolean),
      meta: {
        totalCatalogCount: m.totalCatalogCount ?? 0,
        candidateCount: m.candidateCount ?? 0,
        finalCount: dishes.length,
        filtersHash: s.preparedDeckFiltersHash ?? createFiltersHash(f),
        generatedAt: m.generatedAt ?? null,
        fallbackReason: m.reason ?? null,
        usedPartnerChoices: f.usedPartnerChoices,
        bothConfirmed: f.bothConfirmed,
        ...(m.recommendationMeta
          ? {
              recommendationMeta: m.recommendationMeta,
              algorithm: m.recommendationMeta.algorithm,
            }
          : {}),
      },
    };
  }
  private empty(f: EffectiveDeckFilters, h: string) {
    return {
      status: 'idle',
      dishes: [],
      meta: {
        totalCatalogCount: 0,
        candidateCount: 0,
        finalCount: 0,
        filtersHash: h,
        generatedAt: null,
        fallbackReason: null,
        usedPartnerChoices: f.usedPartnerChoices,
        bothConfirmed: f.bothConfirmed,
      },
    };
  }
}
export {
  buildEffectiveFilters,
  createFiltersHash,
  EffectiveDeckFilters,
} from '../domain/pairDeckPolicy';
