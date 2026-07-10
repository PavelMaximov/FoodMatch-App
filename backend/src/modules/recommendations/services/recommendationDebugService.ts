import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { buildEffectiveFilters } from '../../couples/services/coupleDeckService';
import { DISH_DTO_SELECT } from '../../dishes/dto/dishDto';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { SoloSwipeSessionModel } from '../../solo-swipes/models/SoloSwipeSession';
import { getMatchedExclusionReason } from '../../../shared/ingredients/exclusionMatcher';
import { buildRecommendationDiagnostics, RecommendationMeta } from '../recommendationTypes';

export class RecommendationDebugService {
  async solo(userId: string, sessionId: string, includeDishes = false) {
    this.assertDebugEnabled();
    if (!Types.ObjectId.isValid(sessionId)) throw new AppError('Session not found', 404);
    const session = await SoloSwipeSessionModel.findOne({ _id: sessionId, userId: new Types.ObjectId(userId) });
    if (!session) throw new AppError('Session not found', 404);
    const deckCount = session.deckDishIds.length;
    const remainingCount = Math.max(0, deckCount - session.deckIndex);
    const recommendationMeta = session.recommendationMeta ?? null;
    return {
      sessionId: session.id,
      mode: 'solo',
      status: session.status,
      deckIndex: session.deckIndex,
      preparedDeckCount: deckCount,
      recommendationMeta,
      filters: { effective: session.filter, users: [] },
      diagnostics: {
        emptyDeckRisk: remainingCount === 0,
        hardFiltersActive: (session.filter.exclusions?.length ?? 0) > 0 || (session.filter.diet?.length ?? 0) > 0,
        notes: recommendationMeta?.diagnosticsNotes ?? (remainingCount === 0 ? ['Solo deck has no remaining dishes'] : [])
      },
      ...(includeDishes ? { dishes: await compactDishes(session.deckDishIds, session.filter.exclusions) } : {})
    };
  }

  async pair(userId: string, sessionId: string, includeDishes = false) {
    this.assertDebugEnabled();
    if (!Types.ObjectId.isValid(sessionId)) throw new AppError('Session not found', 404);
    const session = await CoupleSessionModel.findOne({ _id: sessionId, members: new Types.ObjectId(userId) });
    if (!session) throw new AppError('Session not found', 404);
    const deck = session.preparedDeck;
    const effective = buildEffectiveFilters(session, userId);
    const recommendationMeta = deck?.recommendationMeta ?? null;
    const notes = recommendationMeta?.diagnosticsNotes ?? fallbackDiagnostics(recommendationMeta, deck?.dishIds.length ?? 0);
    return {
      sessionId: session.id,
      mode: 'pair',
      status: session.status,
      deckIndex: 0,
      preparedDeckCount: deck?.dishIds.length ?? 0,
      recommendationMeta,
      filters: {
        effective,
        users: (session.filterState?.users ?? []).map((choice) => ({
          userId: choice.userId.toString(),
          cuisines: choice.cuisines,
          moods: choice.moods,
          diet: choice.diet,
          exclusions: choice.exclusions,
          confirmed: choice.confirmed,
          updatedAt: choice.updatedAt
        }))
      },
      diagnostics: {
        emptyDeckRisk: (deck?.dishIds.length ?? 0) === 0 || (recommendationMeta?.finalCount ?? 1) === 0,
        hardFiltersActive: effective.exclusions.length > 0 || effective.diet.length > 0,
        notes
      },
      ...(includeDishes ? { dishes: await compactDishes(deck?.dishIds ?? [], effective.exclusions) } : {})
    };
  }

  private assertDebugEnabled() {
    if (process.env.NODE_ENV === 'production' && process.env.RECOMMENDATION_DEBUG_ENABLED !== 'true') {
      throw new AppError('Recommendation debug endpoint is disabled', 404, 'RECOMMENDATION_DEBUG_DISABLED');
    }
  }
}

async function compactDishes(dishIds: Types.ObjectId[], exclusions: string[]) {
  const dishes = await DishModel.find({ _id: { $in: dishIds } }).select(DISH_DTO_SELECT).lean();
  const byId = new Map((dishes as any[]).map((dish) => [dish._id.toString(), dish]));
  return dishIds.map((id) => byId.get(id.toString())).filter(Boolean).map((dish) => ({
    id: dish._id.toString(),
    name: dish.name,
    cuisine: dish.cuisine,
    type: dish.type,
    matchedHardExclusionReason: getMatchedExclusionReason(dish as DishDocument, exclusions)
  }));
}

function fallbackDiagnostics(meta: RecommendationMeta | null, deckCount: number) {
  if (!meta) return deckCount === 0 ? ['No recommendation metadata persisted for this prepared deck'] : [];
  return buildRecommendationDiagnostics(meta);
}
