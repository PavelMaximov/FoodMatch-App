import crypto from 'crypto';
import { FilterQuery, Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { DISH_DTO_SELECT, toDishDto } from '../../dishes/dto/dishDto';
import { dishMatchesExclusions } from '../../../shared/ingredients/exclusionMatcher';
import { buildPairSharedRecommendedDeck, DeckRecommendationFilters, DeckRecommendationHistoryEntry, RecommendedDeckMeta } from '../../recommendations/deckRecommendationService';
import { logRecommendationMeta, RecommendationMeta } from '../../recommendations/recommendationTypes';
import { SwipeModel } from '../../swipes/models/Swipe';
import { CoupleFilterUserChoice, CoupleSessionDocument, CoupleSessionModel } from '../models/CoupleSession';

export interface EffectiveDeckFilters {
  dishRegisters: string[];
  includeCustomDishesFirst: boolean;
  customFirstUserIds: string[];
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
  algorithm?: RecommendationMeta['algorithm'];
  excludedByExclusionsCount?: number;
  candidateCountAfterExclusions?: number;
  expansionApplied?: boolean;
  expansionReason?: string | null;
}

const MAX_DECK_SIZE = 30;
const PREPARE_WAIT_ATTEMPTS = 6;
const PREPARE_WAIT_MS = 150;

export class CoupleDeckService {
  async prepareDeckForActiveSession(userId: string) {
    let session = await this.requireActiveSession(userId);
    this.assertDeckCanPrepare(session);
    const filters = buildEffectiveFilters(session, userId);
    const filtersHash = createFiltersHash(filters);
    const existingDeck = session.preparedDeck;
    if (this.isReusablePreparedDeck(existingDeck, filtersHash)) {
      console.log(`[PreparedDeck] reuse existing deck session=${session.id} filtersHash=${filtersHash}`);
      const existingDishes = await this.loadPreparedDeckDishes(session);
      return this.toDeckResponse(session, existingDishes, filters, existingDeck?.recommendationMeta ?? undefined);
    }

    if (existingDeck?.status === 'preparing' && existingDeck.filtersHash === filtersHash) {
      const ready = await this.waitForPreparedDeck(session.id, filtersHash);
      if (ready) {
        const readyDishes = await this.loadPreparedDeckDishes(ready);
        return this.toDeckResponse(ready, readyDishes, filters, ready.preparedDeck?.recommendationMeta ?? undefined);
      }
      throw new AppError('Deck is still preparing.', 409, 'DECK_PREPARING', { filtersHash });
    }

    const generatedAt = new Date();
    const lockedSession = await CoupleSessionModel.findOneAndUpdate(
      {
        _id: session._id,
        status: 'active',
        $or: [
          { 'preparedDeck.status': { $ne: 'preparing' } },
          { 'preparedDeck.filtersHash': { $ne: filtersHash } },
          { preparedDeck: { $exists: false } }
        ]
      },
      {
        $set: {
          'preparedDeck.status': 'preparing',
          'preparedDeck.filtersHash': filtersHash,
          'preparedDeck.generatedAt': generatedAt,
          'preparedDeck.generatedBy': new Types.ObjectId(userId)
        }
      },
      { new: true }
    );
    if (!lockedSession) {
      const ready = await this.waitForPreparedDeck(session.id, filtersHash);
      if (ready) {
        const readyDishes = await this.loadPreparedDeckDishes(ready);
        return this.toDeckResponse(ready, readyDishes, filters, ready.preparedDeck?.recommendationMeta ?? undefined);
      }
      throw new AppError('Deck is still preparing.', 409, 'DECK_PREPARING', { filtersHash });
    }
    session = lockedSession;

    try {
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
    const finalDishes = buildCustomFirstPairDeck(
      allDishes,
      result.dishes,
      filters,
      fullySwipedDishIds,
      MAX_DECK_SIZE
    );
    const customIncludedCount = finalDishes.filter((dish) =>
      filters.customFirstUserIds.includes(dish.createdBy?.toString() ?? '')
    ).length;
    const recommendationMeta = {
      ...result.meta,
      finalCount: finalDishes.length,
      customIncludedCount
    };
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
      reason: fallbackReason,
      recommendationMeta: { ...recommendationMeta, filtersHash, bothUsersConfirmed: filters.bothConfirmed }
    };

    console.log(`[PreparedDeck] totalCatalog=${totalCatalogCount} candidates=${candidateCount} final=${finalDishes.length}`);
    console.log(`[PreparedDeck] algorithm=${recommendationMeta.algorithm} excluded=${recommendationMeta.excludedByExclusionsCount} expansion=${recommendationMeta.expansionReason ?? 'none'}`);
    console.log(`[PreparedDeck] filtersHash=${filtersHash}`);
    console.log(`[PreparedDeck] fallback=${fallbackReason}`);
    logRecommendationMeta(recommendationMeta, { sessionId: session.id });

    await session.save();
    console.log(`[PreparedDeck] Saved deck session=${session.id}`);

    return this.toDeckResponse(session, finalDishes, filters, recommendationMeta);
    } catch (error) {
      session.preparedDeck = {
        status: 'failed',
        dishIds: [],
        publicDishIds: [],
        totalCatalogCount: 0,
        candidateCount: 0,
        finalCount: 0,
        filtersHash,
        generatedAt: new Date(),
        generatedBy: new Types.ObjectId(userId),
        reason: 'prepare_failed',
        recommendationMeta: null
      };
      await session.save().catch(() => undefined);
      throw error;
    }
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
    return this.toDeckResponse(session, orderedDishes, filters, deck.recommendationMeta ?? undefined);
  }


  async requestDeckRestart(userId: string) {
    const session = await this.requireActiveSession(userId);
    return this.updateRestartRequest(session, userId, true);
  }

  async getDeckRestartStatus(userId: string) {
    const session = await this.requireActiveSession(userId);
    return this.updateRestartRequest(session, userId, false);
  }

  async resetDeckForActiveSession(userId: string) {
    const session = await this.requireActiveSession(userId);
    clearPreparedDeck(session);
    await session.save();
    console.log(`[PreparedDeck] reset session=${session.id}`);
    return this.emptyDeckResponse('idle', buildEffectiveFilters(session, userId), createFiltersHash(buildEffectiveFilters(session, userId)), null);
  }



  private async updateRestartRequest(session: CoupleSessionDocument, userId: string, shouldRecordRequest: boolean) {
    const memberIds = session.members.map((memberId) => memberId.toString());
    const now = new Date();
    if (!session.restartState) {
      session.restartState = { requestedBy: [], status: 'idle', generation: 0, updatedAt: null };
    }
    if (!Array.isArray(session.restartState.requestedBy)) {
      session.restartState.requestedBy = [];
    }

    if (!shouldRecordRequest && session.restartState.status === 'ready') {
      return this.toRestartResponse(session, memberIds, true);
    }

    if (shouldRecordRequest && !session.restartState.requestedBy.some((id) => id.toString() === userId)) {
      session.restartState.requestedBy.push(new Types.ObjectId(userId));
      session.restartState.updatedAt = now;
    }

    const requestedBy = session.restartState.requestedBy.map((id) => id.toString());
    const allRequested = memberIds.length >= 2 && memberIds.every((memberId) => requestedBy.includes(memberId));

    if (allRequested) {
      clearPreparedDeck(session);
      session.filterState = { users: [], status: 'draft', updatedAt: now };
      session.restartState = {
        requestedBy: [],
        status: 'ready',
        generation: (session.restartState.generation ?? 0) + 1,
        updatedAt: now
      };
      await session.save();
      return this.toRestartResponse(session, memberIds, true);
    }

    session.restartState.status = requestedBy.length > 0 ? 'waiting' : 'idle';
    await session.save();
    return this.toRestartResponse(session, memberIds, false);
  }

  private toRestartResponse(session: CoupleSessionDocument, requiredUserIds: string[], allRequested: boolean) {
    return {
      status: allRequested ? 'ready' : session.restartState?.status ?? 'idle',
      requestedBy: (session.restartState?.requestedBy ?? []).map((id) => id.toString()),
      requiredUserIds,
      allRequested,
      generation: session.restartState?.generation ?? 0
    };
  }

  private assertDeckCanPrepare(session: CoupleSessionDocument) {
    if (session.pairLifecycleState?.status === 'needs_resync') {
      throw new AppError('Pair session needs to be refreshed.', 409, 'PAIR_SESSION_NEEDS_RESYNC', {
        pairLifecycleStatus: session.pairLifecycleState.status,
        lifecycleReason: session.pairLifecycleState.reason,
        generation: session.pairLifecycleState.generation
      });
    }
    const memberIds = session.members.map((memberId) => memberId.toString());
    const users = session.filterState?.users ?? [];
    const allMembersConfirmed = memberIds.length >= 2 && memberIds.every((memberId) => {
      const entry = users.find((user) => user.userId.toString() === memberId);
      return entry?.confirmed === true;
    });

    if (!allMembersConfirmed) {
      console.log(`[PreparedDeck] Waiting for partner filters session=${session.id}`);
      const code = session.pairLifecycleState?.status === 'partner_action_required'
        ? 'PAIR_WAITING_FOR_PARTNER_FILTERS'
        : 'FILTERS_NOT_READY';
      throw new AppError('Waiting for partner to finish filters', 409, code, {
        bothConfirmed: false,
        generation: session.pairLifecycleState?.generation ?? 0
      });
    }
  }

  private async requireActiveSession(userId: string) {
    const session = await CoupleSessionModel.findOne({ members: new Types.ObjectId(userId), status: 'active' }).sort({ updatedAt: -1, createdAt: -1 });
    if (!session) throw new AppError('This pair session is no longer active.', 404, 'PAIR_SESSION_INACTIVE');
    if (!session.filterState) session.filterState = { users: [], status: 'draft', updatedAt: null };
    if (!Array.isArray(session.filterState.users)) session.filterState.users = [];
    return session;
  }

  private isReusablePreparedDeck(deck: CoupleSessionDocument['preparedDeck'], filtersHash: string) {
    return Boolean(
      deck &&
        deck.status === 'ready' &&
        deck.filtersHash === filtersHash &&
        deck.finalCount > 0 &&
        Array.isArray(deck.dishIds) &&
        deck.dishIds.length > 0
    );
  }

  private async waitForPreparedDeck(sessionId: string, filtersHash: string) {
    for (let attempt = 0; attempt < PREPARE_WAIT_ATTEMPTS; attempt += 1) {
      await delay(PREPARE_WAIT_MS);
      const latest = await CoupleSessionModel.findById(sessionId);
      if (latest?.preparedDeck && this.isReusablePreparedDeck(latest.preparedDeck, filtersHash)) {
        console.log(`[PreparedDeck] waited for existing deck session=${sessionId} filtersHash=${filtersHash}`);
        return latest;
      }
      if (!latest?.preparedDeck || latest.preparedDeck.status !== 'preparing' || latest.preparedDeck.filtersHash !== filtersHash) {
        return null;
      }
    }
    return null;
  }

  private async loadPreparedDeckDishes(session: CoupleSessionDocument) {
    const deck = session.preparedDeck;
    if (!deck?.dishIds?.length) return [];
    const dishes = await DishModel.find({ _id: { $in: deck.dishIds } }).select(DISH_DTO_SELECT);
    const visibleDishes = dishes.filter((dish) => isDeckVisibleDish(dish, session));
    const byId = new Map(visibleDishes.map((dish) => [dish._id.toString(), dish]));
    return deck.dishIds
      .map((id) => byId.get(id.toString()))
      .filter((dish): dish is NonNullable<typeof dish> => Boolean(dish));
  }

  private buildVisibilityFilter(session: CoupleSessionDocument): FilterQuery<DishDocument> {
    const customFirstOwners = (session.filterState?.users ?? [])
      .filter((choice) => choice.includeCustomDishesFirst)
      .map((choice) => choice.userId);
    return {
      $or: [
        { visibility: 'public', status: 'approved' },
        { isCustom: true, visibility: 'session', coupleId: session._id, status: 'approved' },
        ...(customFirstOwners.length > 0
          ? [{ isCustom: true, createdBy: { $in: customFirstOwners }, status: 'approved' }]
          : [])
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

  private toDeckResponse(session: CoupleSessionDocument, dishes: DishDocument[], filters: EffectiveDeckFilters, recommendationMeta?: RecommendationMeta) {
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
        recommendationMeta,
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
    reason: null,
    recommendationMeta: null
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
  const usedPartnerChoices = Boolean(partner && (partner.includeCustomDishesFirst || partnerCuisines.length > 0 || normalizeList(partner.dishRegisters).length > 0 || normalizeList(partner.moods).length > 0 || partnerDiet.length > 0 || normalizeList(partner.exclusions).length > 0));

  return {
    dishRegisters: resolvePairCuisines(normalizeList(mine?.dishRegisters), normalizeList(partner?.dishRegisters)).cuisines,
    includeCustomDishesFirst: Boolean(mine?.includeCustomDishesFirst || partner?.includeCustomDishesFirst),
    customFirstUserIds: users.filter((entry) => entry.includeCustomDishesFirst).map((entry) => entry.userId.toString()).sort(),
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
    dishRegisters: [...filters.dishRegisters].sort(),
    includeCustomDishesFirst: filters.includeCustomDishesFirst,
    customFirstUserIds: [...filters.customFirstUserIds].sort(),
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
    dishRegisters: normalizeList(choice.dishRegisters),
    includeCustomDishesFirst: choice.includeCustomDishesFirst === true,
    cuisines: normalizeList(choice.cuisines),
    moods: normalizeList(choice.moods),
    diet: normalizeList(choice.diet),
    exclusions: normalizeKeys(choice.exclusions)
  };
}

function buildCustomFirstPairDeck(
  allDishes: DishDocument[],
  recommended: DishDocument[],
  filters: EffectiveDeckFilters,
  excludedDishIds: Set<string>,
  deckSize: number
) {
  if (!filters.includeCustomDishesFirst) return recommended;
  const selectedOwners = new Set(filters.customFirstUserIds);
  const byOwner = filters.customFirstUserIds.map((ownerId) => allDishes
    .filter((dish) => dish.isCustom === true && dish.status === 'approved' && dish.createdBy?.toString() === ownerId)
    .filter((dish) => !excludedDishIds.has(dish._id.toString()) && dishPassesPairHardFilters(dish, filters))
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime()));
  const custom: DishDocument[] = [];
  const seen = new Set<string>();
  const maxLength = Math.max(0, ...byOwner.map((items) => items.length));
  for (let index = 0; index < maxLength; index += 1) {
    for (const items of byOwner) {
      const dish = items[index];
      if (dish && !seen.has(dish._id.toString())) {
        seen.add(dish._id.toString());
        custom.push(dish);
      }
    }
  }
  // Legacy session dishes without an owner stay in the recommendation tail.
  const discoveryTarget = Math.max(1, Math.floor(deckSize * 0.2));
  const customPrefix = custom.length >= deckSize - discoveryTarget
    ? custom.slice(0, deckSize - discoveryTarget)
    : custom;
  const tailTarget = deckSize - customPrefix.length;
  const tail = recommended
    .filter((dish) => !seen.has(dish._id.toString()) && (!isSessionCustomDish(dish) || !selectedOwners.has(dish.createdBy?.toString() ?? '')))
    .slice(0, Math.max(0, tailTarget));
  return [...customPrefix, ...tail];
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

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isSessionCustomDish(dish: DishDocument) {
  return dish.isCustom === true && dish.visibility === 'session' && dish.status === 'approved' && Boolean(dish.coupleId);
}

function isSessionCustomDishForCouple(dish: DishDocument, coupleId: Types.ObjectId) {
  return isSessionCustomDish(dish) && dish.coupleId?.toString() === coupleId.toString();
}

function isDeckVisibleDish(dish: DishDocument, session: CoupleSessionDocument) {
  if (dish.visibility === 'public' && dish.status === 'approved') return true;
  if (dish.isCustom && dish.status === 'approved' && session.members.some((member) => member.toString() === dish.createdBy?.toString())) return true;
  return isSessionCustomDishForCouple(dish, session._id as Types.ObjectId);
}
