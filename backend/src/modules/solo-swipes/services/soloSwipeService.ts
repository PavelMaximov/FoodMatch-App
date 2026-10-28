import { AppError } from '../../../core/errors/AppError';
import { isActiveSoloSessionUniqueViolation } from '../../../core/utils/postgresErrors';
import {
  CatalogDish as DishDocument,
  postgresDishes,
} from '../../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import {
  loadMongoDishesInPostgresOrder,
  mongoDishId,
  postgresDishId,
} from '../../../shared/db/dishIdMapping';
import {
  queryPostgres,
  withPostgresTransaction,
} from '../../../shared/db/postgresClient';
import { toDishDto, toPublicDishId } from '../../dishes/dto/dishDto';
import { requireAdvancedFilterAccess } from '../../entitlements/services/featureAccessService';
import { LastFilterPresetService } from '../../filters/services/lastFilterPresetService';
import { RecommendedDeckMeta } from '../../recommendations/deckRecommendationService';
import { logRecommendationMeta } from '../../recommendations/recommendationTypes';
import {
  isUsableOwnedCustomDish,
  NormalizedSoloFilter,
  SoloDeckService,
  SoloFilterInput,
} from './soloDeckService';
export class SoloSwipeService {
  private readonly deckBuilder = new SoloDeckService();
  async getActive(userId: string) {
    const s = await domainRepositories.soloSessions.findActive(userId);
    if (s) await domainRepositories.soloSessions.update(s.id, userId, {});
    return s ? this.toDeck(s) : null;
  }
  async getResumable(userId: string) {
    const s = await domainRepositories.soloSessions.findResumable(userId);
    return s ? this.toDeck(s) : null;
  }
  async createSession(
    userId: string,
    filter: SoloFilterInput,
    options: { startOver?: boolean } = {},
  ) {
    await requireAdvancedFilterAccess(userId, filter);
    const startedAt = Date.now(),
      lookupStarted = Date.now();
    const existing = await domainRepositories.soloSessions.findActive(userId);
    this.logTiming('active lookup', lookupStarted);
    if (existing && !options.startOver) {
      this.logDuration('deck prepare', 0);
      this.logDuration('session write', 0);
      const response = {
        ...(await this.toDeck(existing)),
        resumedExisting: true,
      };
      this.logTiming('total', startedAt);
      return response;
    }
    if (await domainRepositories.coupleSessions.findActiveForUser(userId))
      throw new AppError(
        'You already have an active swipe session.',
        409,
        'ACTIVE_SESSION_EXISTS',
      );
    const normalized = this.deckBuilder.normalizeFilter(filter),
      deckStarted = Date.now(),
      result = await this.deckBuilder.buildDeck(userId, normalized);
    this.logTiming('deck prepare', deckStarted);
    logRecommendationMeta(result.meta);
    const ids = await Promise.all(result.dishes.map(postgresDishId)),
      writeStarted = Date.now();
    try {
      const write = {
        userId,
        deckDishIds: ids,
        filters: normalized,
        algorithm: result.meta.algorithm,
        meta: result.meta as unknown as Record<string, unknown>,
      };
      const created = options.startOver
        ? await domainRepositories.soloSessions.replaceActive(write)
        : await domainRepositories.soloSessions.create(write);
      this.logTiming('session write', writeStarted);
      const response = {
        ...(await this.toDeck(created, result.dishes, result.meta)),
        resumedExisting: false,
      };
      this.logTiming('total', startedAt);
      return response;
    } catch (error) {
      if (!isActiveSoloSessionUniqueViolation(error)) throw error;
      const raced = await domainRepositories.soloSessions.findActive(userId);
      if (!raced)
        throw new AppError(
          'Your solo session could not be resumed. Please try again.',
          409,
          'SOLO_SESSION_ALREADY_ACTIVE',
        );
      this.logTiming('session write', writeStarted);
      const response = { ...(await this.toDeck(raced)), resumedExisting: true };
      this.logTiming('total', startedAt);
      return response;
    }
  }
  async getDeck(userId: string, id: string) {
    const s = await this.requireSession(userId, id);
    return this.toDeck(s);
  }
  async updateActiveFilter(userId: string, filter: SoloFilterInput) {
    return withPostgresTransaction(async () => {
      await queryPostgres(
        "select id from solo_swipe_sessions where user_id=$1 and status='active' for update",
        [userId],
      );
      return this.updateActiveFilterLocked(userId, filter);
    });
  }
  private async updateActiveFilterLocked(
    userId: string,
    filter: SoloFilterInput,
  ) {
    await requireAdvancedFilterAccess(userId, filter);
    const s = await domainRepositories.soloSessions.findActive(userId);
    if (!s)
      throw new AppError('No active solo session', 404, 'NO_ACTIVE_SESSION');
    const normalized = this.deckBuilder.normalizeFilter(filter),
      swipes = await domainRepositories.swipes.listForUserSession(
        userId,
        s.id,
        'solo',
      );
    const oldMongo = await Promise.all(s.deckDishIds.map(mongoDishId));
    const excluded = new Set(
      (await Promise.all(swipes.map((x) => mongoDishId(x.dishId)))).filter(
        (x): x is string => !!x,
      ),
    );
    const result = await this.deckBuilder.buildDeck(
        userId,
        normalized,
        excluded,
        new Set(oldMongo.filter((x): x is string => !!x)),
      ),
      ids = await Promise.all(result.dishes.map(postgresDishId));
    const updated = await domainRepositories.soloSessions.update(s.id, userId, {
      filters: normalized,
      deckDishIds: ids,
      currentIndex: 0,
      meta: result.meta as unknown as Record<string, unknown>,
      algorithm: result.meta.algorithm,
    });
    return this.toDeck(updated!, result.dishes, result.meta);
  }
  async abandonActive(userId: string) {
    const s = await domainRepositories.soloSessions.setStatusForActive(
      userId,
      'abandoned',
    );
    return { ok: true, abandoned: Boolean(s), sessionId: s?.id ?? null };
  }
  async swipe(
    userId: string,
    id: string,
    dishId: string,
    direction: 'like' | 'dislike',
  ) {
    return withPostgresTransaction(async () => {
      await queryPostgres(
        'select id from solo_swipe_sessions where id=$1 and user_id=$2 for update',
        [id, userId],
      );
      return this.swipeLocked(userId, id, dishId, direction);
    });
  }
  private async swipeLocked(
    userId: string,
    id: string,
    dishId: string,
    direction: 'like' | 'dislike',
  ) {
    const startedAt = Date.now(),
      s = await domainRepositories.soloSessions.findByIdForUser(id, userId),
      dish = await postgresDishes.getByPublicId(dishId);
    if (!dish) throw new AppError('This dish is not available.', 404);
    const pg = await postgresDishId(dish);
    if (!s || !['active', 'completed'].includes(s.status))
      throw new AppError('No active solo session', 404, 'NO_ACTIVE_SESSION');
    const previous = (
      await domainRepositories.swipes.listForUserSession(userId, id, 'solo')
    ).find((row) => row.dishId === pg);
    if (previous) {
      if (previous.direction !== direction)
        throw new AppError(
          'Swipe direction conflicts with the saved action.',
          409,
          'SWIPE_CONFLICT',
        );
      const matches = await domainRepositories.matches.listForSoloSession(
        userId,
        id,
      );
      const match = matches.find((row) => row.dishId === pg);
      return {
        id: previous.id,
        dishId: toPublicDishId(dish),
        direction: previous.direction,
        matchCreated: false,
        matchId: match?.id ?? null,
        match: match ? { id: match.id, dishId: toPublicDishId(dish) } : null,
        alreadyMatched: Boolean(match),
        badgeDelta: 0,
        badgeCount: matches.length,
        alreadySwiped: true,
        completed: s.status === 'completed',
        mode: 'solo',
      };
    }
    if (s.status !== 'active' || s.deckDishIds[s.currentIndex] !== pg)
      throw new AppError(
        'Dish is not current in this solo session.',
        409,
        'DISH_NOT_CURRENT',
      );
    if (!this.isSoloVisibleDish(dish, userId))
      throw new AppError('This dish is not available.', 404);
    const beforeCount = (
        await domainRepositories.matches.listForSoloSession(userId, id)
      ).length,
      swipe = await domainRepositories.swipes.createOnce({
        userId,
        dishId: pg,
        mode: 'solo',
        direction,
        soloSessionId: id,
      });
    let matchId: string | null = null,
      repositoryCreated = false;
    if (swipe.swipe.direction === 'like') {
      const m = await domainRepositories.matches.createOnce({
        dishId: pg,
        mode: 'solo',
        userId,
      });
      repositoryCreated = m.created;
      matchId = m.match.id;
    }
    const next = Math.min(s.currentIndex + 1, s.deckDishIds.length),
      completed = next >= s.deckDishIds.length;
    await domainRepositories.soloSessions.update(id, userId, {
      currentIndex: next,
      status: completed ? 'completed' : 'active',
      completedAt: completed ? new Date() : null,
    });
    const badgeCount = (
        await domainRepositories.matches.listForSoloSession(userId, id)
      ).length,
      badgeDelta = badgeCount - beforeCount,
      matchCreated = swipe.swipe.direction === 'like' && badgeDelta > 0,
      alreadyMatched =
        swipe.swipe.direction === 'like' &&
        matchId !== null &&
        !matchCreated &&
        !repositoryCreated;
    if (completed)
      await new LastFilterPresetService().saveLast(userId, {
        mode: 'solo',
        ...(s.filters as NormalizedSoloFilter),
        matchedLastTime: badgeCount,
      });
    if (process.env.NODE_ENV !== 'production')
      console.info(
        `[SwipeResponse] mode=solo direction=${swipe.swipe.direction} beforeCount=${beforeCount} afterCount=${badgeCount} badgeDelta=${badgeDelta} matchCreated=${matchCreated} matchId=${matchId ?? 'none'} duration=${Date.now() - startedAt}`,
      );
    return {
      id: swipe.swipe.id,
      dishId: toPublicDishId(dish),
      direction: swipe.swipe.direction,
      matchCreated,
      matchId,
      match: matchId ? { id: matchId, dishId: toPublicDishId(dish) } : null,
      alreadyMatched,
      badgeDelta,
      badgeCount,
      alreadySwiped: !swipe.created,
      completed,
      mode: 'solo',
    };
  }
  async undo(userId: string, id: string, options: { compact?: boolean } = {}) {
    return withPostgresTransaction(async () => {
      await queryPostgres(
        'select id from solo_swipe_sessions where id=$1 and user_id=$2 for update',
        [id, userId],
      );
      return this.undoLocked(userId, id, options);
    });
  }
  private async undoLocked(
    userId: string,
    id: string,
    options: { compact?: boolean } = {},
  ) {
    const startedAt = Date.now(),
      s = await domainRepositories.soloSessions.findByIdForUser(id, userId);
    if (!s || !['active', 'completed'].includes(s.status))
      throw new AppError('No solo session found', 404, 'NO_ACTIVE_SESSION');
    const beforeMatches = await domainRepositories.matches.listForSoloSession(
        userId,
        id,
      ),
      beforeCount = beforeMatches.length,
      expected = s.deckDishIds[s.currentIndex - 1],
      latest = (
        await domainRepositories.swipes.listForUserSession(userId, id, 'solo')
      )[0],
      swipe =
        expected && latest?.dishId === expected
          ? await domainRepositories.swipes.deleteLatest(userId, id, 'solo')
          : null;
    if (!swipe || swipe.dishId !== expected) {
      const session = await this.toDeck(s),
        undo = {
          success: false,
          undoneSwipeId: null,
          dishId: null,
          direction: null,
          matchRemoved: false,
          removedMatchId: null,
          badgeCount: beforeCount,
          badgeDelta: 0,
        };
      return { undone: false, lastUndoneDishId: null, undo, session };
    }
    const removedMatch =
      swipe.direction === 'like'
        ? beforeMatches.find((match) => match.dishId === swipe.dishId)
        : undefined;
    if (removedMatch)
      await domainRepositories.matches.deleteSolo(userId, swipe.dishId);
    const updated = await domainRepositories.soloSessions.update(id, userId, {
        currentIndex: Math.max(0, s.currentIndex - 1),
        status: 'active',
        completedAt: null,
      }),
      badgeCount = (
        await domainRepositories.matches.listForSoloSession(userId, id)
      ).length,
      badgeDelta = badgeCount - beforeCount,
      matchRemoved = badgeDelta < 0,
      removedMatchId = matchRemoved ? (removedMatch?.id ?? null) : null,
      dishPublicId = await mongoDishId(swipe.dishId),
      undo = {
        success: true,
        undoneSwipeId: swipe.id,
        dishId: dishPublicId,
        direction: swipe.direction,
        matchRemoved,
        removedMatchId,
        badgeCount,
        badgeDelta,
      };
    if (process.env.NODE_ENV !== 'production')
      console.info(
        `[UndoResponse] mode=solo direction=${swipe.direction} beforeCount=${beforeCount} afterCount=${badgeCount} badgeDelta=${badgeDelta} matchRemoved=${matchRemoved} removedMatchId=${removedMatchId ?? 'none'} duration=${Date.now() - startedAt}`,
      );
    return {
      undone: true,
      lastUndoneDishId: dishPublicId,
      undo,
      session: options.compact
        ? {
            sessionId: id,
            status: updated!.status,
            deckUnchanged: true,
            restoredDishId: dishPublicId,
            matchedCount: (
              await domainRepositories.swipes.listForUserSession(
                userId,
                id,
                'solo',
              )
            ).filter((swipe) => swipe.direction === 'like').length,
          }
        : await this.toDeck(updated!),
    };
  }
  async assertNoActiveSession(userId: string) {
    const [solo, pair] = await Promise.all([
      domainRepositories.soloSessions.findActive(userId),
      domainRepositories.coupleSessions.findActiveForUser(userId),
    ]);
    if (solo || pair)
      throw new AppError(
        'You already have an active swipe session.',
        409,
        'ACTIVE_SESSION_EXISTS',
      );
  }

  private async requireSession(u: string, id: string) {
    const s = await domainRepositories.soloSessions.findByIdForUser(id, u);
    if (!s || s.status !== 'active')
      throw new AppError('No active solo session', 404, 'NO_ACTIVE_SESSION');
    return s;
  }
  private async toDeck(
    s: any,
    loaded?: DishDocument[],
    meta?: RecommendedDeckMeta,
  ) {
    const ids = s.deckDishIds.slice(s.currentIndex),
      dishes = loaded ?? (await loadMongoDishesInPostgresOrder(ids)),
      sessionSwipes = await domainRepositories.swipes.listForUserSession(
        s.userId,
        s.id,
        'solo',
      );
    return {
      sessionId: s.id,
      mode: 'solo',
      status: s.status,
      deckIndex: s.currentIndex,
      matchedCount: sessionSwipes.filter((swipe) => swipe.direction === 'like')
        .length,
      filter: s.filters,
      dishes: dishes.map(toDishDto).filter(Boolean),
      meta: {
        totalCatalogCount:
          (meta ?? s.meta)?.totalCatalogCount ?? s.deckDishIds.length,
        candidateCount:
          (meta ?? s.meta)?.candidateCount ?? s.deckDishIds.length,
        finalCount: ids.length,
        usedPartnerChoices: false,
        bothConfirmed: false,
        recommendationMeta: meta ?? s.meta,
        algorithm: (meta ?? s.meta)?.algorithm,
      },
    };
  }

  private isSoloVisibleDish(d: DishDocument, u: string) {
    return (
      (d.visibility === 'public' && d.status === 'approved') ||
      isUsableOwnedCustomDish(d, u)
    );
  }
  private logTiming(label: string, startedAt: number) {
    this.logDuration(label, Date.now() - startedAt);
  }
  private logDuration(label: string, duration: number) {
    if (process.env.NODE_ENV !== 'production')
      console.info(`[SoloSession] ${label} ms=${duration}`);
  }
}
