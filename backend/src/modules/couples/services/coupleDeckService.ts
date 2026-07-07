import crypto from 'crypto';
import { FilterQuery, Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { DISH_DTO_SELECT, toDishDto } from '../../dishes/dto/dishDto';
import { dishMatchesExclusions } from '../../../shared/ingredients/exclusionMatcher';
import { buildPairSharedRecommendedDeck, DeckRecommendationFilters, DeckRecommendationHistoryEntry, RecommendedDeckMeta } from '../../recommendations/deckRecommendationService';
import { SwipeModel } from '../../swipes/models/Swipe';
import { CoupleFilterUserChoice, CoupleSessionDocument, CoupleSessionModel } from '../models/CoupleSession';

export interface EffectiveDeckFilters {
  cuisines: string[];
  moods: string[];
  diet: string[];
  exclusions: string[];
  usedCuisineUnionFallback: boolean;
  usedPartnerChoices: boolean;
  bothConfirmed: boolean;
}

interface DeckResponseMeta {
  totalCatalogCount: number;
  candidateCount: number;
  finalCount: number;
  filtersHash: string;
  generatedAt: Date | null;
  fallbackReason: string | null;
  usedPartnerChoices: boolean;
  bothConfirmed: boolean;
  algorithm?: RecommendedDeckMeta['algorithm'];
  excludedByExclusionsCount?: number;
  candidateCountAfterExclusions?: number;
  expansionApplied?: boolean;
  expansionReason?: string | null;
}

const MAX_DECK_SIZE = 30;

export class CoupleDeckService {
  async prepareDeckForActiveSession(userId: string) {
    const session = await this.requireActiveSession(userId);
    this.assertDeckCanPrepare(session);
    const filters = buildEffectiveFilters(session, userId);
    const filtersHash = createFiltersHash(filters);
    const generatedAt = new Date();

    console.log(`[PreparedDeck] Preparing deck session=${session.id}`);

    const visibilityFilter = this.buildVisibilityFilter(session);
    const allDishes = await DishModel.find(visibilityFilter).select(DISH_DTO_SELECT);
    const totalCatalogCount = allDishes.length;

    const [userContexts, fullySwipedDishIds] = await Promise.all([
      this.buildPairUserContexts(session),
      this.loadFullySwipedDishIds(session)
    ]);
    const customDishIds = new Set(allDishes.filter(isSessionCustomDish).map((dish) => dish._id.toString()));
    const result = buildPairSharedRecommendedDeck({
      users: userContexts,
      dishes: allDishes,
      hardFilters: filters,
      excludedDishIds: fullySwipedDishIds,
      deckSize: MAX_DECK_SIZE,
      customDishIds
    });
    const finalDishes = result.dishes;
    const recommendationMeta = result.meta;
    const fallbackReason: string | null = recommendationMeta.expansionReason ?? (filters.usedCuisineUnionFallback ? 'No common cuisine — scoring both preferences.' : null);
    const candidateCount = recommendationMeta.candidateCount;
    const dishIds = finalDishes.map((dish) => dish._id as Types.ObjectId);
    const publicDishIds = finalDishes.map((dish) => toDishDto(dish)?.id ?? '').filter((id) => id.length > 0);

    session.preparedDeck = {
      status: 'ready',
      dishIds,
      publicDishIds,
      totalCatalogCount,
      candidateCount,
      finalCount: finalDishes.length,
      filtersHash,
      generatedAt,
      generatedBy: new Types.ObjectId(userId),
      reason: fallbackReason
    };

    console.log(`[PreparedDeck] totalCatalog=${totalCatalogCount} candidates=${candidateCount} final=${finalDishes.length}`);
    console.log(`[PreparedDeck] algorithm=${recommendationMeta.algorithm} excluded=${recommendationMeta.excludedByExclusionsCount} expansion=${recommendationMeta.expansionReason ?? 'none'}`);
    console.log(`[PreparedDeck] filtersHash=${filtersHash}`);
    console.log(`[PreparedDeck] fallback=${fallbackReason}`);

    await session.save();
    console.log(`[PreparedDeck] Saved deck session=${session.id}`);

    return this.toDeckResponse(session, finalDishes, filters, recommendationMeta);
  }

  async getDeckForActiveSession(userId: string) {
    const session = await this.requireActiveSession(userId);
    const filters = buildEffectiveFilters(session, userId);
    const filtersHash = createFiltersHash(filters);
    const deck = session.preparedDeck;

    if (!deck || deck.status !== 'ready' || !deck.filtersHash || deck.filtersHash !== filtersHash || deck.dishIds.length === 0) {
      return this.emptyDeckResponse(deck?.status ?? 'idle', filters, filtersHash, deck?.reason ?? null);
    }

    const dishes = await DishModel.find({ _id: { $in: deck.dishIds } }).select(DISH_DTO_SELECT);
    const visibleDishes = dishes.filter((dish) => isDeckVisibleDish(dish, session));
    const byId = new Map(visibleDishes.map((dish) => [dish._id.toString(), dish]));
    const orderedDishes = deck.dishIds
      .map((id) => byId.get(id.toString()))
      .filter((dish): dish is NonNullable<typeof dish> => Boolean(dish));

    console.log(`[PreparedDeck] loaded existing deck final=${orderedDishes.length}`);
    return this.toDeckResponse(session, orderedDishes, filters);
  }

  async resetDeckForActiveSession(userId: string) {
    const session = await this.requireActiveSession(userId);
    clearPreparedDeck(session);
    await session.save();
    console.log(`[PreparedDeck] reset session=${session.id}`);
    return this.emptyDeckResponse('idle', buildEffectiveFilters(session, userId), createFiltersHash(buildEffectiveFilters(session, userId)), null);
  }


  private assertDeckCanPrepare(session: CoupleSessionDocument) {
    const memberIds = session.members.map((memberId) => memberId.toString());
    const users = session.filterState?.users ?? [];
    const allMembersConfirmed = memberIds.length >= 2 && memberIds.every((memberId) => {
      const entry = users.find((user) => user.userId.toString() === memberId);
      return entry?.confirmed === true;
    });

    if (!allMembersConfirmed) {
      console.log(`[PreparedDeck] Waiting for partner filters session=${session.id}`);
      throw new AppError('Waiting for partner to finish filters', 409, 'FILTERS_NOT_READY', { bothConfirmed: false });
    }
  }

  private async requireActiveSession(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' });
    if (!session) throw new AppError('No active session', 404);
    if (!session.filterState) session.filterState = { users: [], status: 'draft', updatedAt: null };
    if (!Array.isArray(session.filterState.users)) session.filterState.users = [];
    return session;
  }

  private buildVisibilityFilter(session: CoupleSessionDocument): FilterQuery<DishDocument> {
    return {
      $or: [
        { visibility: 'public', status: 'approved' },
        { isCustom: true, visibility: 'session', coupleId: session._id, status: 'approved' }
      ]
    };
  }


  private async buildPairUserContexts(session: CoupleSessionDocument) {
    const choices = session.filterState?.users ?? [];
    const previousPreparedDeckIds = new Set((session.preparedDeck?.dishIds ?? []).map((id) => id.toString()));
    const [histories, activeSwipes] = await Promise.all([
      Promise.all(choices.map(async (choice) => ({ userId: choice.userId.toString(), history: await this.loadUserHistory(choice.userId) }))),
      SwipeModel.find({ coupleId: session._id }).select('userId dishId direction').lean()
    ]);
    const historyByUser = new Map(histories.map((entry) => [entry.userId, entry.history]));
    const swipedByUser = new Map<string, Set<string>>();
    for (const swipe of activeSwipes as any[]) {
      const swipeUserId = swipe.userId?.toString();
      const dishId = swipe.dishId?.toString();
      if (!swipeUserId || !dishId) continue;
      const set = swipedByUser.get(swipeUserId) ?? new Set<string>();
      set.add(dishId);
      swipedByUser.set(swipeUserId, set);
    }
    return choices.map((choice) => {
      const userId = choice.userId.toString();
      return {
        userId,
        filters: filtersFromChoice(choice),
        userHistory: historyByUser.get(userId) ?? [],
        recencyScores: buildPairRecencyScores(swipedByUser.get(userId) ?? new Set<string>(), previousPreparedDeckIds)
      };
    });
  }

  private async loadUserHistory(userId: Types.ObjectId): Promise<DeckRecommendationHistoryEntry[]> {
    const swipes = await SwipeModel.find({ userId }).select('dishId direction').populate({ path: 'dishId', select: DISH_DTO_SELECT }).sort({ createdAt: -1 }).limit(100).lean();
    const history: DeckRecommendationHistoryEntry[] = [];
    for (const swipe of swipes as any[]) {
      if (swipe?.dishId && (swipe.direction === 'like' || swipe.direction === 'dislike')) {
        history.push({ dish: swipe.dishId as DishDocument, direction: swipe.direction });
      }
    }
    return history;
  }

  private async loadFullySwipedDishIds(session: CoupleSessionDocument) {
    const memberIds = new Set(session.members.map((id) => id.toString()));
    const swipes = await SwipeModel.find({ coupleId: session._id }).select('userId dishId').lean();
    const usersByDish = new Map<string, Set<string>>();
    for (const swipe of swipes as any[]) {
      const userId = swipe.userId?.toString();
      const dishId = swipe.dishId?.toString();
      if (!userId || !dishId || !memberIds.has(userId)) continue;
      const set = usersByDish.get(dishId) ?? new Set<string>();
      set.add(userId);
      usersByDish.set(dishId, set);
    }
    return new Set([...usersByDish.entries()].filter(([, users]) => users.size >= memberIds.size).map(([dishId]) => dishId));
  }

  private toDeckResponse(session: CoupleSessionDocument, dishes: DishDocument[], filters: EffectiveDeckFilters, recommendationMeta?: RecommendedDeckMeta) {
    const deck = session.preparedDeck;
    const dishDtos = dishes.map((dish) => toDishDto(dish)).filter((dish): dish is NonNullable<ReturnType<typeof toDishDto>> => Boolean(dish));
    const meta: DeckResponseMeta = {
      totalCatalogCount: deck?.totalCatalogCount ?? 0,
      candidateCount: deck?.candidateCount ?? 0,
      finalCount: dishDtos.length,
      filtersHash: deck?.filtersHash ?? createFiltersHash(filters),
      generatedAt: deck?.generatedAt ?? null,
      fallbackReason: deck?.reason ?? null,
      usedPartnerChoices: filters.usedPartnerChoices,
      bothConfirmed: filters.bothConfirmed,
      ...(recommendationMeta ? {
        algorithm: recommendationMeta.algorithm,
        excludedByExclusionsCount: recommendationMeta.excludedByExclusionsCount,
        candidateCountAfterExclusions: recommendationMeta.candidateCountAfterExclusions,
        expansionApplied: recommendationMeta.expansionApplied,
        expansionReason: recommendationMeta.expansionReason ?? null
      } : {})
    };

    return { status: deck?.status ?? 'idle', dishes: dishDtos, meta };
  }

  private emptyDeckResponse(status: string, filters: EffectiveDeckFilters, filtersHash: string, fallbackReason: string | null) {
    return {
      status,
      dishes: [],
      meta: {
        totalCatalogCount: 0,
        candidateCount: 0,
        finalCount: 0,
        filtersHash,
        generatedAt: null,
        fallbackReason,
        usedPartnerChoices: filters.usedPartnerChoices,
        bothConfirmed: filters.bothConfirmed
      }
    };
  }
}


export async function addSessionCustomDishToPreparedDeck(coupleId: Types.ObjectId, dish: DishDocument, reason = 'session_custom_dish_added') {
  if (!isSessionCustomDishForCouple(dish, coupleId)) return;

  const session = await CoupleSessionModel.findById(coupleId);
  const deck = session?.preparedDeck;
  if (!session || !deck || deck.status !== 'ready' || deck.dishIds.length === 0) return;
  if (!dishPassesPairHardFilters(dish, buildEffectiveFilters(session))) return;

  const dishId = dish._id as Types.ObjectId;
  const dishIdString = dishId.toString();
  const existingIndex = deck.dishIds.findIndex((id) => id.toString() === dishIdString);
  const withoutDuplicate = deck.dishIds.filter((id) => id.toString() !== dishIdString);
  const withoutDuplicatePublicIds = deck.publicDishIds.filter((_, index) => index !== existingIndex);
  deck.dishIds = [dishId, ...withoutDuplicate];
  deck.publicDishIds = [toDishDto(dish)?.id ?? dishIdString, ...withoutDuplicatePublicIds];
  deck.totalCatalogCount = Math.max(deck.totalCatalogCount, deck.dishIds.length);
  deck.candidateCount = Math.max(deck.candidateCount, deck.dishIds.length);
  deck.finalCount = deck.dishIds.length;
  deck.generatedAt = new Date();
  deck.reason = reason;
  await session.save();
}

export async function removeSessionCustomDishFromPreparedDeck(coupleId: Types.ObjectId, dish: DishDocument, reason = 'session_custom_dish_removed') {
  const session = await CoupleSessionModel.findById(coupleId);
  const deck = session?.preparedDeck;
  if (!session || !deck || deck.status !== 'ready' || deck.dishIds.length === 0) return;

  const dishIdString = (dish._id as Types.ObjectId).toString();
  const nextDishIds = deck.dishIds.filter((id) => id.toString() !== dishIdString);
  if (nextDishIds.length === deck.dishIds.length) return;

  deck.dishIds = nextDishIds;
  deck.publicDishIds = deck.publicDishIds.filter((id) => id !== toDishDto(dish)?.id && id !== dishIdString);
  deck.finalCount = nextDishIds.length;
  deck.candidateCount = Math.min(deck.candidateCount, nextDishIds.length);
  deck.generatedAt = new Date();
  deck.reason = reason;
  await session.save();
}

export function clearPreparedDeck(session: CoupleSessionDocument) {
  session.preparedDeck = {
    status: 'idle',
    dishIds: [],
    publicDishIds: [],
    totalCatalogCount: 0,
    candidateCount: 0,
    finalCount: 0,
    filtersHash: '',
    generatedAt: null,
    generatedBy: null,
    reason: null
  };
}

export function buildEffectiveFilters(session: CoupleSessionDocument, userId?: string): EffectiveDeckFilters {
  const users = session.filterState?.users ?? [];
  const mine = userId ? users.find((entry) => entry.userId.toString() === userId) : users[0];
  const partner = userId ? users.find((entry) => entry.userId.toString() !== userId) : users[1];

  const myCuisines = normalizeList(mine?.cuisines);
  const partnerCuisines = normalizeList(partner?.cuisines);
  const cuisineResult = resolvePairCuisines(myCuisines, partnerCuisines);

  const myDiet = normalizeList(mine?.diet);
  const partnerDiet = normalizeList(partner?.diet);
  const diet = resolveDiet(myDiet, partnerDiet);
  const bothConfirmed = Boolean(mine && partner && mine.confirmed && partner.confirmed);
  const usedPartnerChoices = Boolean(partner && (partnerCuisines.length > 0 || normalizeList(partner.moods).length > 0 || partnerDiet.length > 0 || normalizeList(partner.exclusions).length > 0));

  return {
    cuisines: cuisineResult.cuisines,
    moods: normalizeList([...(mine?.moods ?? []), ...(partner?.moods ?? [])]),
    diet,
    exclusions: normalizeKeys([...(mine?.exclusions ?? []), ...(partner?.exclusions ?? [])]),
    usedCuisineUnionFallback: cuisineResult.usedUnionFallback,
    usedPartnerChoices,
    bothConfirmed
  };
}

export function createFiltersHash(filters: EffectiveDeckFilters) {
  const stable = {
    cuisines: [...filters.cuisines].sort(),
    moods: [...filters.moods].sort(),
    diet: [...filters.diet].sort(),
    exclusions: [...filters.exclusions].sort(),
    usedPartnerChoices: filters.usedPartnerChoices,
    bothConfirmed: filters.bothConfirmed
  };
  return crypto.createHash('sha1').update(JSON.stringify(stable)).digest('hex');
}


function dishPassesPairHardFilters(dish: DishDocument, filters: EffectiveDeckFilters) {
  if (dishMatchesExclusions(dish, filters.exclusions)) return false;
  return matchesStrictPairDiet(dish, filters.diet);
}

function matchesStrictPairDiet(dish: DishDocument, diet: string[]) {
  const dishDiet = normalizeList(dish.diet);
  if (diet.includes('vegan')) return dishDiet.includes('vegan');
  if (diet.includes('vegetarian')) return dishDiet.includes('vegetarian') || dishDiet.includes('vegan');
  return true;
}

function filtersFromChoice(choice: CoupleFilterUserChoice): DeckRecommendationFilters {
  return {
    cuisines: normalizeList(choice.cuisines),
    moods: normalizeList(choice.moods),
    diet: normalizeList(choice.diet),
    exclusions: normalizeKeys(choice.exclusions)
  };
}

function buildPairRecencyScores(userSwipedDishIds: Set<string>, previousPreparedDeckIds: Set<string>) {
  const scores = new Map<string, number>();
  for (const dishId of previousPreparedDeckIds) scores.set(dishId, 0.5);
  for (const dishId of userSwipedDishIds) scores.set(dishId, 0.35);
  return scores;
}

function resolvePairCuisines(myCuisines: string[], partnerCuisines: string[]) {
  if (myCuisines.length === 0 && partnerCuisines.length === 0) return { cuisines: [], usedUnionFallback: false };
  if (myCuisines.length === 0) return { cuisines: partnerCuisines, usedUnionFallback: false };
  if (partnerCuisines.length === 0) return { cuisines: myCuisines, usedUnionFallback: false };
  const partnerSet = new Set(partnerCuisines);
  const intersection = myCuisines.filter((cuisine) => partnerSet.has(cuisine));
  if (intersection.length > 0) return { cuisines: [...new Set(intersection)].sort(), usedUnionFallback: false };
  return { cuisines: [...new Set([...myCuisines, ...partnerCuisines])].sort(), usedUnionFallback: true };
}

function resolveDiet(myDiet: string[], partnerDiet: string[]) {
  if (myDiet.length === 0 && partnerDiet.length === 0) return [];
  if (myDiet.length === 0) return partnerDiet;
  if (partnerDiet.length === 0) return myDiet;
  const partnerSet = new Set(partnerDiet);
  const intersection = myDiet.filter((diet) => partnerSet.has(diet));
  return intersection.length > 0 ? [...new Set(intersection)].sort() : [...new Set([...myDiet, ...partnerDiet])].sort();
}

function normalizeList(values?: string[]) {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.map((value) => normalize(value)).filter((value) => value.length > 0 && value !== 'any'))].sort();
}

function normalizeKeys(values?: string[]) {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.map((value) => (value ?? '').trim().toLowerCase()).filter((value) => value.length > 0 && value !== 'any'))].sort();
}

function normalize(value?: string) {
  return (value ?? '').trim().toLowerCase().replace(/_/g, ' ');
}


function isSessionCustomDish(dish: DishDocument) {
  return dish.isCustom === true && dish.visibility === 'session' && dish.status === 'approved' && Boolean(dish.coupleId);
}

function isSessionCustomDishForCouple(dish: DishDocument, coupleId: Types.ObjectId) {
  return isSessionCustomDish(dish) && dish.coupleId?.toString() === coupleId.toString();
}

function isDeckVisibleDish(dish: DishDocument, session: CoupleSessionDocument) {
  if (dish.visibility === 'public' && dish.status === 'approved') return true;
  return isSessionCustomDishForCouple(dish, session._id as Types.ObjectId);
}
