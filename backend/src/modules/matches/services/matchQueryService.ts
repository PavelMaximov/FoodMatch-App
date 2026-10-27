import { AppError } from '../../../core/errors/AppError';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { loadDishesById } from '../../../shared/db/dishIdMapping';
import { toDishDto } from '../../dishes/dto/dishDto';
export class MatchQueryService {
  async getMyMatches(
    userId: string,
    mode: 'solo' | 'paired' | 'all' = 'all',
    options: { scope?: 'current' | 'all'; sessionId?: string } = {},
  ) {
    let rows;
    let resolvedSoloSessionId: string | undefined;
    if (mode === 'solo' && options.scope === 'current') {
      const session = options.sessionId
        ? await domainRepositories.soloSessions.findByIdForUser(
            options.sessionId,
            userId,
          )
        : await domainRepositories.soloSessions.findActive(userId);
      if (options.sessionId && !session)
        throw new AppError(
          'This solo session is not available.',
          403,
          'SOLO_SESSION_FORBIDDEN',
        );
      resolvedSoloSessionId = session?.id;
      if (!resolvedSoloSessionId) return [];
      rows = await domainRepositories.matches.listForSoloSession(
        userId,
        resolvedSoloSessionId,
      );
    } else {
      rows = await domainRepositories.matches.listForUser(
        userId,
        mode === 'all' ? undefined : mode,
      );
    }
    const dishes = await loadDishesById(rows.map((r) => r.dishId));
    return rows
      .map((m) => {
        const dish = toDishDto(dishes.get(m.dishId));
        if (!dish) return null;
        return {
          id: m.id,
          coupleId: m.coupleSessionId,
          sessionId:
            m.mode === 'solo' ? resolvedSoloSessionId : m.coupleSessionId,
          users: m.mode === 'paired' ? [] : [userId],
          dish,
          createdAt: m.createdAt,
          mode: m.mode,
          matchType: m.mode === 'solo' ? 'solo_pick' : 'pair_match',
        };
      })
      .filter(Boolean);
  }
  async getMySwipeHistory(userId: string) {
    const s = await domainRepositories.coupleSessions.findActiveForUser(userId);
    if (!s) throw new AppError('User has no active session', 404);
    const rows = await domainRepositories.swipes.listForUserSession(
        userId,
        s.id,
        'paired',
      ),
      dishes = await loadDishesById(rows.map((r) => r.dishId));
    return rows
      .map((r) => ({
        id: r.id,
        direction: r.direction,
        createdAt: r.createdAt,
        dish: toDishDto(dishes.get(r.dishId)),
      }))
      .filter((x) => x.dish);
  }
}
