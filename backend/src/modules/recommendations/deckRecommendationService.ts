import { Types } from 'mongoose';
import { DishDocument } from '../dishes/models/Dish';
import { dishMatchesExclusions } from '../../shared/ingredients/exclusionMatcher';

export const WEIGHTED_SCORING_MVP_ALGORITHM = 'weighted_scoring_mvp_v1' as const;
export const WEIGHTED_SCORING_PAIR_SHARED_MVP_ALGORITHM = 'weighted_scoring_pair_shared_mvp_v1' as const;

export interface DeckRecommendationFilters {
  cuisines: string[];
  moods: string[];
  diet: string[];
  exclusions: string[];
}

export interface DeckRecommendationHistoryEntry {
  dish: DishDocument;
  direction: 'like' | 'dislike';
}

export interface BuildRecommendedDeckInput {
  userId: string;
  dishes: DishDocument[];
  filters: DeckRecommendationFilters;
  userHistory?: DeckRecommendationHistoryEntry[];
  recentlySeenDishIds?: Set<string>;
  excludedDishIds?: Set<string>;
  deckSize: number;
  mode: 'solo' | 'paired';
}

export interface RecommendedDeckMeta {
  totalCatalogCount: number;
  candidateCount: number;
  finalCount: number;
  algorithm: typeof WEIGHTED_SCORING_MVP_ALGORITHM | typeof WEIGHTED_SCORING_PAIR_SHARED_MVP_ALGORITHM;
  excludedByExclusionsCount: number;
  candidateCountAfterExclusions: number;
  expansionApplied: boolean;
  expansionReason?: 'low_candidates_after_exclusions' | 'critical_candidates_after_exclusions';
}

export interface BuildRecommendedDeckResult {
  dishes: DishDocument[];
  meta: RecommendedDeckMeta;
}

export interface PairRecommendedDeckUserInput {
  userId: string;
  filters: DeckRecommendationFilters;
  userHistory?: DeckRecommendationHistoryEntry[];
  recencyScores?: Map<string, number>;
}

export interface BuildPairRecommendedDeckInput {
  users: PairRecommendedDeckUserInput[];
  dishes: DishDocument[];
  hardFilters: DeckRecommendationFilters;
  excludedDishIds?: Set<string>;
  deckSize: number;
  customDishIds?: Set<string>;
}

interface ScoredDish {
  dish: DishDocument;
  score: number;
  components: {
    countryScore: number;
    moodScore: number;
    historyScore: number;
    popularityScore: number;
    recencyScore: number;
  };
}

const COLD_WEIGHTS = { country: 0.35, mood: 0.30, history: 0.05, popularity: 0.20, recency: 0.10 };
const WARM_WEIGHTS = { country: 0.20, mood: 0.20, history: 0.35, popularity: 0.15, recency: 0.10 };
const LOW_CANDIDATE_THRESHOLD = 15;
const CRITICAL_CANDIDATE_THRESHOLD = 5;
const DEFAULT_EXPLORE_SHARE = 0.25;
const EXPANDED_EXPLORE_SHARE = 0.5;

export function buildRecommendedDeck(input: BuildRecommendedDeckInput): BuildRecommendedDeckResult {
  const filters = normalizeFilters(input.filters);
  const excludedDishIds = input.excludedDishIds ?? new Set<string>();
  const recentlySeenDishIds = input.recentlySeenDishIds ?? new Set<string>();
  const totalCatalogCount = input.dishes.length;

  let excludedByExclusionsCount = 0;
  const afterExplicitExcludes = input.dishes.filter((dish) => {
    const dishId = dish._id instanceof Types.ObjectId ? dish._id.toString() : String(dish._id ?? '');
    return !excludedDishIds.has(dishId);
  });
  const afterExclusions = afterExplicitExcludes.filter((dish) => {
    const matched = dishMatchesExclusions(dish, filters.exclusions);
    if (matched) excludedByExclusionsCount += 1;
    return !matched;
  });
  const candidates = afterExclusions.filter((dish) => matchesStrictDiet(dish, filters.diet));

  let expansionReason: RecommendedDeckMeta['expansionReason'];
  if (candidates.length < CRITICAL_CANDIDATE_THRESHOLD) {
    expansionReason = 'critical_candidates_after_exclusions';
  } else if (candidates.length < LOW_CANDIDATE_THRESHOLD) {
    expansionReason = 'low_candidates_after_exclusions';
  }

  if (expansionReason) {
    console.log('[filter_expansion_event]', {
      algorithm: WEIGHTED_SCORING_MVP_ALGORITHM,
      mode: input.mode,
      userId: input.userId,
      excludedByExclusionsCount,
      candidateCountAfterExclusions: afterExclusions.length,
      candidateCount: candidates.length,
      reason: expansionReason
    });
  }

  const scored = scoreCandidates({
    candidates,
    filters,
    history: input.userHistory ?? [],
    recentlySeenDishIds,
    criticalCandidates: expansionReason === 'critical_candidates_after_exclusions'
  });

  const selected = pickCoreAndExplore(scored, input.deckSize, expansionReason ? EXPANDED_EXPLORE_SHARE : DEFAULT_EXPLORE_SHARE)
    .map((scoredDish) => scoredDish.dish);

  return {
    dishes: selected,
    meta: {
      totalCatalogCount,
      excludedByExclusionsCount,
      candidateCountAfterExclusions: afterExclusions.length,
      candidateCount: candidates.length,
      finalCount: selected.length,
      algorithm: WEIGHTED_SCORING_MVP_ALGORITHM,
      expansionApplied: Boolean(expansionReason),
      ...(expansionReason ? { expansionReason } : {})
    }
  };
}


export function buildPairSharedRecommendedDeck(input: BuildPairRecommendedDeckInput): BuildRecommendedDeckResult {
  const hardFilters = normalizeFilters(input.hardFilters);
  const excludedDishIds = input.excludedDishIds ?? new Set<string>();
  const totalCatalogCount = input.dishes.length;

  let excludedByExclusionsCount = 0;
  const afterExplicitExcludes = input.dishes.filter((dish) => !excludedDishIds.has(getDishId(dish)));
  const afterExclusions = afterExplicitExcludes.filter((dish) => {
    const matched = dishMatchesExclusions(dish, hardFilters.exclusions);
    if (matched) excludedByExclusionsCount += 1;
    return !matched;
  });
  const candidates = afterExclusions.filter((dish) => matchesStrictDiet(dish, hardFilters.diet));

  let expansionReason: RecommendedDeckMeta['expansionReason'];
  if (candidates.length < CRITICAL_CANDIDATE_THRESHOLD) {
    expansionReason = 'critical_candidates_after_exclusions';
  } else if (candidates.length < LOW_CANDIDATE_THRESHOLD) {
    expansionReason = 'low_candidates_after_exclusions';
  }

  if (expansionReason) {
    console.log('[filter_expansion_event]', {
      algorithm: WEIGHTED_SCORING_PAIR_SHARED_MVP_ALGORITHM,
      mode: 'paired',
      userIds: input.users.map((user) => user.userId),
      excludedByExclusionsCount,
      candidateCountAfterExclusions: afterExclusions.length,
      candidateCount: candidates.length,
      reason: expansionReason
    });
  }

  const normalizedUsers = input.users.map((user) => ({
    ...user,
    filters: normalizeFilters(user.filters),
    userHistory: user.userHistory ?? [],
    recencyScores: user.recencyScores ?? new Map<string, number>()
  }));

  const scored = candidates.map((dish) => {
    const userScores = normalizedUsers.map((user) => scoreDishForUser({
      dish,
      filters: user.filters,
      history: user.userHistory,
      recencyScores: user.recencyScores,
      criticalCandidates: expansionReason === 'critical_candidates_after_exclusions'
    }));
    const pairScore = blendPairScores(userScores.map((score) => score.score));
    const customBoost = input.customDishIds?.has(getDishId(dish)) ? 0.20 : 0;
    return { dish, score: pairScore + customBoost, components: userScores[0]?.components ?? neutralComponents() };
  }).sort((a, b) => b.score - a.score || getDishName(a.dish).localeCompare(getDishName(b.dish)) || getDishId(a.dish).localeCompare(getDishId(b.dish)));

  const selected = pickCoreAndExplore(scored, input.deckSize, expansionReason ? EXPANDED_EXPLORE_SHARE : DEFAULT_EXPLORE_SHARE)
    .map((scoredDish) => scoredDish.dish);

  return {
    dishes: selected,
    meta: {
      totalCatalogCount,
      excludedByExclusionsCount,
      candidateCountAfterExclusions: afterExclusions.length,
      candidateCount: candidates.length,
      finalCount: selected.length,
      algorithm: WEIGHTED_SCORING_PAIR_SHARED_MVP_ALGORITHM,
      expansionApplied: Boolean(expansionReason),
      ...(expansionReason ? { expansionReason } : {})
    }
  };
}

function scoreCandidates({
  candidates,
  filters,
  history,
  recentlySeenDishIds,
  criticalCandidates
}: {
  candidates: DishDocument[];
  filters: DeckRecommendationFilters;
  history: DeckRecommendationHistoryEntry[];
  recentlySeenDishIds: Set<string>;
  criticalCandidates: boolean;
}): ScoredDish[] {
  return candidates.map((dish) => scoreDishForUser({
    dish,
    filters,
    history,
    recentlySeenDishIds,
    criticalCandidates
  })).sort((a, b) => b.score - a.score || getDishName(a.dish).localeCompare(getDishName(b.dish)) || getDishId(a.dish).localeCompare(getDishId(b.dish)));
}

function scoreDishForUser({
  dish,
  filters,
  history,
  recentlySeenDishIds,
  recencyScores,
  criticalCandidates
}: {
  dish: DishDocument;
  filters: DeckRecommendationFilters;
  history: DeckRecommendationHistoryEntry[];
  recentlySeenDishIds?: Set<string>;
  recencyScores?: Map<string, number>;
  criticalCandidates: boolean;
}): ScoredDish {
  const totalMeaningfulSwipes = history.length;
  const warmth = clamp(totalMeaningfulSwipes / 50, 0, 1);
  const weights = interpolateWeights(warmth, criticalCandidates);
  const historyTags = buildHistoryTags(history);
  const components = {
    countryScore: countryScore(dish, filters.cuisines),
    moodScore: moodScore(dish, filters.moods),
    historyScore: historyScore(dish, historyTags),
    popularityScore: popularityScore(dish),
    recencyScore: recencyScores?.get(getDishId(dish)) ?? recencyScore(dish, recentlySeenDishIds ?? new Set<string>())
  };
  const score =
    weights.country * components.countryScore +
    weights.mood * components.moodScore +
    weights.history * components.historyScore +
    weights.popularity * components.popularityScore +
    weights.recency * components.recencyScore;
  return { dish, score, components };
}

function blendPairScores(scores: number[]) {
  if (scores.length === 0) return 0;
  if (scores.length === 1) return scores[0];
  const average = scores.reduce((sum, score) => sum + score, 0) / scores.length;
  const minimum = Math.min(...scores);
  return 0.65 * average + 0.35 * minimum;
}

function neutralComponents(): ScoredDish['components'] {
  return { countryScore: 0.5, moodScore: 0.5, historyScore: 0.5, popularityScore: 0.3, recencyScore: 1.0 };
}

function interpolateWeights(warmth: number, criticalCandidates: boolean) {
  if (criticalCandidates) {
    return { country: 0, mood: 0, history: 0.10, popularity: 0.60, recency: 0.30 };
  }
  return {
    country: COLD_WEIGHTS.country * (1 - warmth) + WARM_WEIGHTS.country * warmth,
    mood: COLD_WEIGHTS.mood * (1 - warmth) + WARM_WEIGHTS.mood * warmth,
    history: COLD_WEIGHTS.history * (1 - warmth) + WARM_WEIGHTS.history * warmth,
    popularity: COLD_WEIGHTS.popularity * (1 - warmth) + WARM_WEIGHTS.popularity * warmth,
    recency: COLD_WEIGHTS.recency * (1 - warmth) + WARM_WEIGHTS.recency * warmth
  };
}

function pickCoreAndExplore(scored: ScoredDish[], deckSize: number, exploreShare: number): ScoredDish[] {
  if (scored.length <= deckSize) return scored;

  const exploreCount = Math.max(0, Math.min(deckSize, Math.floor(deckSize * exploreShare)));
  const coreCount = deckSize - exploreCount;
  const corePool = scored.slice(0, coreCount);
  const coreIds = new Set(corePool.map((item) => getDishId(item.dish)));
  const percentileStart = Math.floor(scored.length * 0.50);
  const percentileEnd = Math.max(percentileStart + 1, Math.ceil(scored.length * 0.80));
  const exploreCandidates = scored.slice(percentileStart, percentileEnd).filter((item) => !coreIds.has(getDishId(item.dish)));
  const explorePool = weightedPick(exploreCandidates.length > 0 ? exploreCandidates : scored.slice(coreCount).filter((item) => !coreIds.has(getDishId(item.dish))), exploreCount);

  return [...corePool, ...explorePool].slice(0, deckSize);
}

function weightedPick(candidates: ScoredDish[], count: number): ScoredDish[] {
  const remaining = [...candidates];
  const picked: ScoredDish[] = [];
  while (picked.length < count && remaining.length > 0) {
    const totalWeight = remaining.reduce((sum, item) => sum + Math.max(item.score, 0.05), 0);
    let cursor = seededRandom(remaining.map((item) => `${getDishId(item.dish)}:${item.score.toFixed(4)}`).join('|'), picked.length) * totalWeight;
    let index = 0;
    for (; index < remaining.length; index += 1) {
      cursor -= Math.max(remaining[index].score, 0.05);
      if (cursor <= 0) break;
    }
    picked.push(remaining.splice(Math.min(index, remaining.length - 1), 1)[0]);
  }
  return picked;
}

function countryScore(dish: DishDocument, cuisines: string[]) {
  if (cuisines.length === 0) return 0.5;
  return cuisines.includes(normalize(dish.cuisine)) ? 1.0 : 0.1;
}

function moodScore(dish: DishDocument, moods: string[]) {
  if (moods.length === 0) return 0.5;
  const dishMoods = normalizeList(dish.mood);
  if (dishMoods.length === 0) return 0.2;
  const matched = moods.filter((mood) => dishMoods.includes(mood)).length;
  return clamp(matched / moods.length, 0, 1);
}

function popularityScore(dish: DishDocument) {
  const base = dish.popular ? 1.0 : 0.3;
  const quality = Number((dish as any).qualityScore ?? (dish as any).quality_score ?? (dish as any).rawSourceData?.quality_score ?? 0);
  const normalizedQuality = Number.isFinite(quality) ? clamp(quality / 100, 0, 1) : 0;
  return Math.max(base, normalizedQuality);
}

function recencyScore(dish: DishDocument, recentlySeenDishIds: Set<string>) {
  return recentlySeenDishIds.has(getDishId(dish)) ? 0.3 : 1.0;
}

function historyScore(dish: DishDocument, historyTags: { liked: Set<string>; disliked: Set<string>; hasHistory: boolean }) {
  if (!historyTags.hasHistory) return 0.5;
  const tags = dishTags(dish);
  const likedOverlap = overlapRatio(tags, historyTags.liked);
  const dislikedOverlap = overlapRatio(tags, historyTags.disliked);
  return clamp(0.5 + likedOverlap * 0.4 - dislikedOverlap * 0.3, 0, 1);
}

function buildHistoryTags(history: DeckRecommendationHistoryEntry[]) {
  const liked = new Set<string>();
  const disliked = new Set<string>();
  for (const entry of history) {
    const target = entry.direction === 'like' ? liked : disliked;
    for (const tag of dishTags(entry.dish)) target.add(tag);
  }
  return { liked, disliked, hasHistory: history.length > 0 };
}

function dishTags(dish: DishDocument) {
  return new Set([
    normalize(dish.cuisine),
    normalize(dish.type),
    normalize(dish.effort),
    ...normalizeList(dish.mood),
    ...normalizeList(dish.diet),
    ...normalizeList(dish.ingredients),
    ...normalizeList(dish.source),
    ...normalizeList(dish.season)
  ].filter(Boolean));
}

function overlapRatio(candidateTags: Set<string>, historyTags: Set<string>) {
  if (candidateTags.size === 0 || historyTags.size === 0) return 0;
  let matches = 0;
  for (const tag of candidateTags) {
    if (historyTags.has(tag)) matches += 1;
  }
  return matches / candidateTags.size;
}

function matchesStrictDiet(dish: DishDocument, diet: string[]) {
  const dishDiet = normalizeList(dish.diet);
  if (diet.includes('vegan')) return dishDiet.includes('vegan');
  if (diet.includes('vegetarian')) return dishDiet.includes('vegetarian') || dishDiet.includes('vegan');
  return true;
}

function normalizeFilters(filters: DeckRecommendationFilters): DeckRecommendationFilters {
  return {
    cuisines: normalizeList(filters.cuisines),
    moods: normalizeList(filters.moods),
    diet: normalizeList(filters.diet),
    exclusions: normalizeList(filters.exclusions).map((value) => value.replace(/ /g, '_'))
  };
}

function normalizeList(values?: string[]) {
  if (!Array.isArray(values)) return [];
  return [...new Set(values.map(normalize).filter(Boolean))];
}

function normalize(value?: string) {
  return (value ?? '').trim().toLowerCase().replace(/_/g, ' ');
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function getDishId(dish: DishDocument) {
  return dish._id instanceof Types.ObjectId ? dish._id.toString() : String(dish._id ?? '');
}

function getDishName(dish: DishDocument) {
  return (dish.name ?? '').trim().toLowerCase();
}

function seededRandom(seed: string, offset: number) {
  let hash = 2166136261 + offset;
  for (let i = 0; i < seed.length; i += 1) {
    hash ^= seed.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) / 4294967295;
}
