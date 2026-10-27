import { AppError } from '../../../core/errors/AppError';
import { postgresDishes } from '../../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { postgresDishId } from '../../../shared/db/dishIdMapping';
import {
  queryPostgres,
  withPostgresTransaction,
} from '../../../shared/db/postgresClient';
import { toPublicDishId } from '../../dishes/dto/dishDto';
import { MatchQueryService } from '../../matches/services/matchQueryService';
export class SwipeService {
  async createSwipe(
    userId: string,
    dishId: string,
    direction: 'like' | 'dislike',
    expectedSessionId?: string,
  ) {
    return withPostgresTransaction(async () => {
      const active =
        await domainRepositories.coupleSessions.findActiveForUser(userId);
      if (!active)
        throw new AppError('No active session', 409, 'NO_ACTIVE_SESSION');
      if (expectedSessionId && active.id !== expectedSessionId)
        throw new AppError(
          'Swipe session has changed.',
          409,
          'SWIPE_SESSION_CHANGED',
        );
      await queryPostgres(
        'select id from couple_sessions where id=$1 for update',
        [active.id],
      );
      return this.createSwipeLocked(userId, dishId, direction, active.id);
    });
  }
  private async createSwipeLocked(
    userId: string,
    dishId: string,
    direction: 'like' | 'dislike',
    expectedSessionId?: string,
  ) {
    const startedAt = Date.now(),
      session =
        await domainRepositories.coupleSessions.findActiveForUser(userId);
    if (!session)
      throw new AppError('No active session', 409, 'NO_ACTIVE_SESSION');
    if (expectedSessionId && session.id !== expectedSessionId)
      throw new AppError(
        'Swipe session has changed.',
        409,
        'SWIPE_SESSION_CHANGED',
      );
    const dish = await postgresDishes.getByPublicId(dishId);
    if (!dish) throw new AppError('This dish is not available.', 404);
    const pgDish = await postgresDishId(dish);
    const inDeck = session.preparedDeckDishIds.includes(pgDish);
    if (
      !(dish.visibility === 'public' && dish.status === 'approved') &&
      !(dish.isCustom && dish.status === 'approved' && inDeck)
    )
      throw new AppError('This dish is not available.', 404);
    const beforeCount = (
        await domainRepositories.matches.listForCouple(session.id)
      ).length,
      result = await domainRepositories.swipes.createOnce({
        userId,
        dishId: pgDish,
        mode: 'paired',
        direction,
        coupleSessionId: session.id,
      });
    if (result.swipe.direction !== direction) {
      throw new AppError(
        'Swipe direction conflicts with the saved action.',
        409,
        'SWIPE_CONFLICT',
      );
    }
    let matchId: string | null = null;
    if (
      result.swipe.direction === 'like' &&
      (await domainRepositories.swipes.countLikes(
        session.id,
        pgDish,
        'paired',
      )) >= 2
    ) {
      const match = await domainRepositories.matches.createOnce({
        dishId: pgDish,
        mode: 'paired',
        coupleSessionId: session.id,
      });
      matchId = match.match.id;
    }
    const badgeCount = (
        await domainRepositories.matches.listForCouple(session.id)
      ).length,
      badgeDelta = badgeCount - beforeCount,
      matchCreated = result.swipe.direction === 'like' && badgeDelta > 0,
      alreadyMatched =
        result.swipe.direction === 'like' && matchId !== null && !matchCreated;
    if (process.env.NODE_ENV !== 'production')
      console.info(
        `[SwipeResponse] mode=paired direction=${result.swipe.direction} beforeCount=${beforeCount} afterCount=${badgeCount} badgeDelta=${badgeDelta} matchCreated=${matchCreated} matchId=${matchId ?? 'none'} duration=${Date.now() - startedAt}`,
      );
    return {
      id: result.swipe.id,
      userId,
      coupleId: session.id,
      dishId: toPublicDishId(dish),
      direction: result.swipe.direction,
      matchCreated,
      matchId,
      match: matchId ? { id: matchId, dishId: toPublicDishId(dish) } : null,
      alreadyMatched,
      badgeDelta,
      badgeCount,
      alreadySwiped: !result.created,
    };
  }
  getMyMatches(...args: Parameters<MatchQueryService['getMyMatches']>) {
    return new MatchQueryService().getMyMatches(...args);
  }
  getMySwipeHistory(
    ...args: Parameters<MatchQueryService['getMySwipeHistory']>
  ) {
    return new MatchQueryService().getMySwipeHistory(...args);
  }
}
