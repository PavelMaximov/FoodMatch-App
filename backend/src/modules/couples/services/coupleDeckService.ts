import crypto from 'crypto';
import { FilterQuery, Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { toDishDto } from '../../dishes/dto/dishDto';
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
}

const EXCLUSION_GROUPS: Record<string, string[]> = {
  no_meat: ['meat', 'chicken', 'beef', 'pork', 'lamb'],
  no_dairy: ['milk', 'cheese', 'cream', 'butter', 'yogurt', 'mozzarella', 'parmesan', 'feta'],
  no_gluten: ['flour', 'bread', 'pasta', 'wheat', 'spaghetti', 'lasagna sheets', 'pita', 'ciabatta'],
  no_nuts: ['peanut', 'peanuts', 'almond', 'almonds', 'walnut', 'walnuts', 'cashew', 'cashews'],
  no_seafood: ['fish', 'salmon', 'shrimp', 'prawn', 'prawns', 'tuna', 'mussels', 'seafood']
};

const MAX_DECK_SIZE = 30;
const NARROW_CHOICE_THRESHOLD = 5;

export class CoupleDeckService {
  async prepareDeckForActiveSession(userId: string) {
    const session = await this.requireActiveSession(userId);
    this.assertDeckCanPrepare(session);
    const filters = buildEffectiveFilters(session, userId);
    const filtersHash = createFiltersHash(filters);
    const generatedAt = new Date();

    console.log(`[PreparedDeck] Preparing deck session=${session.id}`);

    const visibilityFilter = this.buildVisibilityFilter(session);
    const allDishes = await DishModel.find(visibilityFilter);
    const totalCatalogCount = allDishes.length;

    let candidateDishes = applyHardFilters(allDishes, filters);
    let fallbackReason: string | null = filters.usedCuisineUnionFallback ? 'No common cuisine — showing both preferences.' : null;

    if (candidateDishes.length === 0 && filters.cuisines.length > 0) {
      const widenedFilters = { ...filters, cuisines: [] };
      candidateDishes = applyHardFilters(allDishes, widenedFilters);
      fallbackReason = 'No dishes matched cuisines, so cuisine was widened.';
    } else if (candidateDishes.length > 0 && candidateDishes.length < NARROW_CHOICE_THRESHOLD && !fallbackReason) {
      fallbackReason = 'Very narrow choice.';
    }

    const candidateCount = candidateDishes.length;
    const finalDishes = scoreAndSortDishes(candidateDishes, filters).slice(0, MAX_DECK_SIZE);
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
    console.log(`[PreparedDeck] filtersHash=${filtersHash}`);
    console.log(`[PreparedDeck] fallback=${fallbackReason}`);

    await session.save();
    console.log(`[PreparedDeck] Saved deck session=${session.id}`);

    return this.toDeckResponse(session, finalDishes, filters);
  }

  async getDeckForActiveSession(userId: string) {
    const session = await this.requireActiveSession(userId);
    const filters = buildEffectiveFilters(session, userId);
    const filtersHash = createFiltersHash(filters);
    const deck = session.preparedDeck;

    if (!deck || deck.status !== 'ready' || !deck.filtersHash || deck.filtersHash !== filtersHash || deck.dishIds.length === 0) {
      return this.emptyDeckResponse(deck?.status ?? 'idle', filters, filtersHash, deck?.reason ?? null);
    }

    const dishes = await DishModel.find({ _id: { $in: deck.dishIds } });
    const byId = new Map(dishes.map((dish) => [dish._id.toString(), dish]));
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
        { sourceType: { $ne: 'custom' }, status: { $ne: 'deleted' } },
        { sourceType: 'custom', coupleId: session._id, status: 'active' }
      ]
    };
  }

  private toDeckResponse(session: CoupleSessionDocument, dishes: DishDocument[], filters: EffectiveDeckFilters) {
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
      bothConfirmed: filters.bothConfirmed
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

export function scoreDishForDeck(dish: DishDocument, filters: EffectiveDeckFilters) {
  let score = 0;
  const cuisine = normalize(dish.cuisine);
  if (filters.cuisines.includes(cuisine)) score += 30;

  const dishMoods = normalizeList(dish.mood);
  for (const mood of filters.moods) {
    if (dishMoods.includes(mood)) score += 15;
  }

  if (dish.popular) score += 10;
  score += Number((dish as any).qualityScore ?? (dish as any).rawSourceData?.quality_score ?? 0) || 0;

  if (dish.cookTime > 0 && dish.cookTime <= 30) score += 3;
  else if (dish.cookTime > 0 && dish.cookTime <= 60) score += 1;

  return score;
}

function scoreAndSortDishes(dishes: DishDocument[], filters: EffectiveDeckFilters) {
  return [...dishes].sort((a, b) => {
    const scoreCompare = scoreDishForDeck(b, filters) - scoreDishForDeck(a, filters);
    if (scoreCompare !== 0) return scoreCompare;
    const nameCompare = a.name.toLowerCase().localeCompare(b.name.toLowerCase());
    if (nameCompare !== 0) return nameCompare;
    return a._id.toString().localeCompare(b._id.toString());
  });
}

function applyHardFilters(dishes: DishDocument[], filters: EffectiveDeckFilters) {
  return dishes.filter((dish) => {
    const cuisine = normalize(dish.cuisine);
    if (filters.cuisines.length > 0 && !filters.cuisines.includes(cuisine)) return false;
    if (!matchesDiet(dish, filters.diet)) return false;
    if (hasExcludedIngredient(dish, filters.exclusions)) return false;
    return true;
  });
}

function matchesDiet(dish: DishDocument, diet: string[]) {
  if (diet.length === 0) return true;
  const dishDiet = normalizeList(dish.diet);
  if (diet.includes('vegan')) return dishDiet.includes('vegan');
  if (diet.includes('vegetarian')) return dishDiet.includes('vegetarian') || dishDiet.includes('vegan');
  return diet.every((value) => dishDiet.includes(value));
}

function hasExcludedIngredient(dish: DishDocument, exclusions: string[]) {
  const blockedWords = exclusions.flatMap((exclusion) => EXCLUSION_GROUPS[exclusion] ?? []);
  if (blockedWords.length === 0) return false;

  const structuredIngredients = Array.isArray(dish.structuredIngredients)
    ? dish.structuredIngredients.map((ingredient) => ingredient.name)
    : [];
  const ingredients = (structuredIngredients.length > 0 ? structuredIngredients : dish.ingredients).map((ingredient) => normalize(ingredient));

  return ingredients.some((ingredient) => blockedWords.some((blocked) => ingredient.includes(normalize(blocked))));
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
