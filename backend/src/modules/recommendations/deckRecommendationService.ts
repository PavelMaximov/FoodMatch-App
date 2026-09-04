import { CatalogDish as DishDocument } from '../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { dishMatchesExclusions } from '../../shared/ingredients/exclusionMatcher';
import { buildRecommendationDiagnostics, RecommendationAlgorithm, RecommendationMeta } from './recommendationTypes';

export const WEIGHTED_SCORING_MVP_ALGORITHM = 'weighted_scoring_mvp_v1' as const;
export const WEIGHTED_SCORING_PAIR_SHARED_MVP_ALGORITHM = 'weighted_scoring_pair_shared_mvp_v1' as const;
export const WEIGHTED_SCORING_PAIR_SHARED_V2_ALGORITHM = 'weighted_scoring_pair_shared_v2' as const;
export const SCORING_VERSION = 'weighted_category_cuisine_v1' as const;
export const MIN_THRESHOLD = 10;
export const CRITICAL_THRESHOLD = 5;
export const MIN_STRONG_SCORE = 0.45;

export interface DeckRecommendationFilters {
  /** Canonical category field. dishRegisters remains a backwards-compatible alias. */
  selectedCategories?: string[];
  dishRegisters?: string[];
  includeCustomDishesFirst?: boolean;
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

export interface RecommendedDeckMeta extends RecommendationMeta {
  totalCatalogCount: number;
  candidateCount: number;
  finalCount: number;
  algorithm: RecommendationAlgorithm;
  excludedByExclusionsCount: number;
  candidateCountAfterExclusions: number;
  expansionApplied: boolean;
  expansionLevel: 'none' | 'category_relaxed' | 'cuisine_expanded' | 'critical';
  availableCount: number;
  strongCandidateCount: number;
  expansionReason?: 'low_candidates_after_exclusions' | 'critical_candidates_after_exclusions' | 'low_pair_candidates_after_hard_filters' | 'critical_pair_candidates_after_hard_filters';
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
    dishRegisterScore: number;
    historyScore: number;
    popularityScore: number;
    recencyScore: number;
  };
}

const COLD_WEIGHTS = { country: 0.30, mood: 0.05, dishRegister: 0.30, history: 0.05, popularity: 0.20, recency: 0.10 };
const WARM_WEIGHTS = { country: 0.18, mood: 0.05, dishRegister: 0.20, history: 0.32, popularity: 0.15, recency: 0.10 };
const LOW_CANDIDATE_THRESHOLD = 15;
const CRITICAL_CANDIDATE_THRESHOLD = 5;
export const PAIR_SCORE_FLOOR = 0.05;

export function buildRecommendedDeck(input: BuildRecommendedDeckInput): BuildRecommendedDeckResult {
  const filters = normalizeFilters(input.filters);
  const excludedDishIds = input.excludedDishIds ?? new Set<string>();
  const recentlySeenDishIds = input.recentlySeenDishIds ?? new Set<string>();
  const totalCatalogCount = input.dishes.length;

  let excludedByExclusionsCount = 0;
  const afterExplicitExcludes = input.dishes.filter((dish) => {
    const dishId = String(dish._id ?? dish.id ?? '');
    return !excludedDishIds.has(dishId);
  });
  const afterExclusions = afterExplicitExcludes.filter((dish) => {
    const matched = dishMatchesExclusions(dish, filters.exclusions);
    if (matched) excludedByExclusionsCount += 1;
    return !matched;
  });
  const candidates = afterExclusions.filter((dish) => matchesStrictDiet(dish, filters.diet));
  const excludedByDietCount = afterExclusions.length - candidates.length;

  const initialScores = candidates.map((dish) => weightedPreferenceScore(dish, filters, recencyScore(dish, recentlySeenDishIds)));
  const strongCandidateCount = initialScores.filter((score) => score >= MIN_STRONG_SCORE).length;
  let expansionReason: RecommendedDeckMeta['expansionReason'];
  if (candidates.length < CRITICAL_THRESHOLD) {
    expansionReason = 'critical_candidates_after_exclusions';
  } else if (candidates.length < MIN_THRESHOLD || strongCandidateCount < MIN_THRESHOLD) {
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

  const selection = pickHighestScored(scored, input.deckSize);
  const selected = selection.items.map((scoredDish) => scoredDish.dish);

  return {
    dishes: selected,
    meta: {
      algorithm: WEIGHTED_SCORING_MVP_ALGORITHM,
      mode: 'solo',
      generatedAt: new Date().toISOString(),
      deckSize: input.deckSize,
      totalDishCount: totalCatalogCount,
      visibleDishCount: totalCatalogCount,
      candidateCountBeforeHardFilters: afterExplicitExcludes.length,
      excludedByExclusionsCount,
      excludedByDietCount,
      fullyConsumedExcludedCount: excludedDishIds.size,
      candidateCountAfterHardFilters: candidates.length,
      scoredCandidateCount: scored.length,
      finalCount: selected.length,
      coreCount: selection.coreCount,
      exploreCount: selection.exploreCount,
      expansionApplied: Boolean(expansionReason),
      expansionLevel: expansionLevel(expansionReason, strongCandidateCount),
      availableCount: candidates.length,
      strongCandidateCount,
      ...(expansionReason ? { expansionReason } : {}),
      hardFilterSummary: { exclusions: filters.exclusions, strictDiet: filters.diet },
      diagnosticsNotes: buildRecommendationDiagnostics({ visibleDishCount: totalCatalogCount, excludedByExclusionsCount, excludedByDietCount, candidateCountAfterHardFilters: candidates.length, finalCount: selected.length }),
      totalCatalogCount,
      candidateCount: candidates.length,
      candidateCountAfterExclusions: afterExclusions.length
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
  const excludedByDietCount = afterExclusions.length - candidates.length;

  const strongCandidateCount = candidates.filter((dish) => input.users.every((user) => weightedPreferenceScore(dish, normalizeFilters(user.filters), 1) >= MIN_STRONG_SCORE)).length;
  let expansionReason: RecommendedDeckMeta['expansionReason'];
  if (candidates.length < CRITICAL_THRESHOLD) {
    expansionReason = 'critical_pair_candidates_after_hard_filters' as RecommendedDeckMeta['expansionReason'];
  } else if (candidates.length < MIN_THRESHOLD || strongCandidateCount < MIN_THRESHOLD) {
    expansionReason = 'low_pair_candidates_after_hard_filters' as RecommendedDeckMeta['expansionReason'];
  }

  if (expansionReason) {
    console.log('[filter_expansion_event]', {
      algorithm: WEIGHTED_SCORING_PAIR_SHARED_V2_ALGORITHM,
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
      criticalCandidates: expansionReason === 'critical_pair_candidates_after_hard_filters',
      scoringOptions: {
        moodWeightMultiplier: expansionReason === 'low_pair_candidates_after_hard_filters' ? 0.5 : 1,
        ignoreCuisineAndMood: expansionReason === 'critical_pair_candidates_after_hard_filters'
      }
    }));
    const pairScore = combinePairScoresGeometric(userScores.map((score) => score.score));
    const customBoost = input.customDishIds?.has(getDishId(dish)) ? 0.20 : 0;
    return { dish, score: pairScore + customBoost, components: userScores[0]?.components ?? neutralComponents() };
  }).sort((a, b) => b.score - a.score || getDishName(a.dish).localeCompare(getDishName(b.dish)) || getDishId(a.dish).localeCompare(getDishId(b.dish)));

  const selection = pickHighestScored(scored, input.deckSize);
  const selected = selection.items.map((scoredDish) => scoredDish.dish);

  return {
    dishes: selected,
    meta: {
      algorithm: WEIGHTED_SCORING_PAIR_SHARED_V2_ALGORITHM,
      mode: 'pair',
      generatedAt: new Date().toISOString(),
      deckSize: input.deckSize,
      totalDishCount: totalCatalogCount,
      visibleDishCount: totalCatalogCount,
      candidateCountBeforeHardFilters: afterExplicitExcludes.length,
      excludedByExclusionsCount,
      excludedByDietCount,
      fullyConsumedExcludedCount: excludedDishIds.size,
      candidateCountAfterHardFilters: candidates.length,
      scoredCandidateCount: scored.length,
      finalCount: selected.length,
      coreCount: selection.coreCount,
      exploreCount: selection.exploreCount,
      expansionApplied: Boolean(expansionReason),
      expansionLevel: expansionLevel(expansionReason, strongCandidateCount),
      availableCount: candidates.length,
      strongCandidateCount,
      ...(expansionReason ? { expansionReason } : {}),
      pairCombineFunction: 'geometric_mean',
      pairScoreFloor: PAIR_SCORE_FLOOR,
      commonPool: true,
      poolOverlapRate: 1.0,
      exploreStrategy: 'pair_score_percentile_50_80',
      customCandidateCount: input.customDishIds ? input.dishes.filter((dish) => input.customDishIds?.has(getDishId(dish))).length : 0,
      customIncludedCount: input.customDishIds ? selected.filter((dish) => input.customDishIds?.has(getDishId(dish))).length : 0,
      customExcludedCount: input.customDishIds ? input.dishes.filter((dish) => input.customDishIds?.has(getDishId(dish))).length - afterExclusions.filter((dish) => input.customDishIds?.has(getDishId(dish)) && matchesStrictDiet(dish, hardFilters.diet)).length : 0,
      customBoostAppliedCount: input.customDishIds ? scored.filter((item) => input.customDishIds?.has(getDishId(item.dish))).length : 0,
      userContextCount: normalizedUsers.length,
      hardFilterSummary: { exclusions: hardFilters.exclusions, strictDiet: hardFilters.diet },
      diagnosticsNotes: buildRecommendationDiagnostics({ visibleDishCount: totalCatalogCount, excludedByExclusionsCount, excludedByDietCount, candidateCountAfterHardFilters: candidates.length, finalCount: selected.length, customCandidateCount: input.customDishIds ? input.dishes.filter((dish) => input.customDishIds?.has(getDishId(dish))).length : 0, customExcludedCount: input.customDishIds ? input.dishes.filter((dish) => input.customDishIds?.has(getDishId(dish))).length - afterExclusions.filter((dish) => input.customDishIds?.has(getDishId(dish)) && matchesStrictDiet(dish, hardFilters.diet)).length : 0 }),
      totalCatalogCount,
      candidateCount: candidates.length,
      candidateCountAfterExclusions: afterExclusions.length
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
  criticalCandidates,
  scoringOptions
}: {
  dish: DishDocument;
  filters: DeckRecommendationFilters;
  history: DeckRecommendationHistoryEntry[];
  recentlySeenDishIds?: Set<string>;
  recencyScores?: Map<string, number>;
  criticalCandidates: boolean;
  scoringOptions?: { moodWeightMultiplier?: number; ignoreCuisineAndMood?: boolean };
}): ScoredDish {
  const totalMeaningfulSwipes = history.length;
  const warmth = clamp(totalMeaningfulSwipes / 50, 0, 1);
  const weights = applyScoringOptions(interpolateWeights(warmth, criticalCandidates), scoringOptions);
  const historyTags = buildHistoryTags(history);
  const components = {
    countryScore: countryScore(dish, filters.cuisines),
    moodScore: moodScore(dish, filters.moods),
    dishRegisterScore: dishRegisterScore(dish, filters.dishRegisters ?? []),
    historyScore: historyScore(dish, historyTags),
    popularityScore: popularityScore(dish),
    recencyScore: recencyScores?.get(getDishId(dish)) ?? recencyScore(dish, recentlySeenDishIds ?? new Set<string>())
  };
  // Category and cuisine own the primary recommendation score. Existing learned
  // signals are retained as a small deterministic tie-break contribution.
  const preference = weightedPreferenceScore(dish, filters, components.recencyScore, criticalCandidates);
  const learned = weights.mood * components.moodScore + weights.history * components.historyScore +
    weights.popularity * components.popularityScore;
  const score = preference + learned * 0.001;
  return { dish, score, components };
}

export function combinePairScoresGeometric(scores: number[]) {
  if (scores.length === 0) return PAIR_SCORE_FLOOR;
  if (scores.length === 1) return Math.max(scores[0], PAIR_SCORE_FLOOR);
  const product = scores.reduce((value, score) => value * Math.max(score, 0), 1);
  return Math.max(Math.pow(product, 1 / scores.length), PAIR_SCORE_FLOOR);
}

function neutralComponents(): ScoredDish['components'] {
  return { countryScore: 0.5, moodScore: 0.5, dishRegisterScore: 0.5, historyScore: 0.5, popularityScore: 0.3, recencyScore: 1.0 };
}

function applyScoringOptions(weights: ReturnType<typeof interpolateWeights>, options?: { moodWeightMultiplier?: number; ignoreCuisineAndMood?: boolean }) {
  if (options?.ignoreCuisineAndMood) return { ...weights, country: 0, mood: 0 };
  if (typeof options?.moodWeightMultiplier === 'number') return { ...weights, mood: weights.mood * options.moodWeightMultiplier };
  return weights;
}

function interpolateWeights(warmth: number, criticalCandidates: boolean) {
  if (criticalCandidates) {
    return { country: 0, mood: 0, dishRegister: 0, history: 0.10, popularity: 0.60, recency: 0.30 };
  }
  return {
    country: COLD_WEIGHTS.country * (1 - warmth) + WARM_WEIGHTS.country * warmth,
    mood: COLD_WEIGHTS.mood * (1 - warmth) + WARM_WEIGHTS.mood * warmth,
    dishRegister: COLD_WEIGHTS.dishRegister * (1 - warmth) + WARM_WEIGHTS.dishRegister * warmth,
    history: COLD_WEIGHTS.history * (1 - warmth) + WARM_WEIGHTS.history * warmth,
    popularity: COLD_WEIGHTS.popularity * (1 - warmth) + WARM_WEIGHTS.popularity * warmth,
    recency: COLD_WEIGHTS.recency * (1 - warmth) + WARM_WEIGHTS.recency * warmth
  };
}

function pickHighestScored(scored: ScoredDish[], deckSize: number): { items: ScoredDish[]; coreCount: number; exploreCount: number } {
  const items = scored.slice(0, deckSize);
  return { items, coreCount: items.length, exploreCount: 0 };
}

const CUISINE_CLUSTERS = [
  ['italian','greek','spanish','turkish','mediterranean','it','gr','es','tr'],
  ['balkan','serbian','croatian','bosnian','bulgarian','romanian','ukrainian','polish','eastern_european','rs','hr','ba','bg','ro','ua','pl'],
  ['french','german','austrian','dutch','belgian','british','fr','de','at','nl','be','gb'],
  ['japanese','korean','chinese','jp','kr','cn'], ['thai','vietnamese','indonesian','malaysian','filipino','th','vn','id','my','ph'],
  ['indian','pakistani','bangladeshi','sri_lankan','in','pk','bd','lk'], ['lebanese','syrian','israeli','iranian','middle_eastern','lb','sy','il','ir'],
  ['mexican','brazilian','peruvian','argentinian','latin_american','mx','br','pe','ar'], ['american','canadian','us','ca'],
  ['international','fusion','other']
].map((items) => new Set(items));

export function cuisineScore(dish: DishDocument, cuisines: string[]) {
  const selected = cuisines.map(canonicalCuisine).filter(Boolean);
  if (!selected.length) return 0.5;
  const actual = canonicalCuisine(dish.cuisine);
  return Math.max(...selected.map((value) => value === actual ? 1 : CUISINE_CLUSTERS.some((cluster) => cluster.has(value) && cluster.has(actual)) ? 0.6 : 0.2));
}

const COUNTRY_CUISINES: Record<string, string> = {
  it:'italian', gr:'greek', es:'spanish', tr:'turkish', rs:'serbian', hr:'croatian', ba:'bosnian', bg:'bulgarian', ro:'romanian', ua:'ukrainian', pl:'polish',
  fr:'french', de:'german', at:'austrian', nl:'dutch', be:'belgian', gb:'british', jp:'japanese', kr:'korean', cn:'chinese', th:'thai', vn:'vietnamese',
  id:'indonesian', my:'malaysian', ph:'filipino', in:'indian', pk:'pakistani', bd:'bangladeshi', lk:'sri_lankan', lb:'lebanese', sy:'syrian', il:'israeli',
  ir:'iranian', mx:'mexican', br:'brazilian', pe:'peruvian', ar:'argentinian', us:'american', ca:'canadian'
};
function canonicalCuisine(value?: string) { const slug = normalizeSlug(value); return COUNTRY_CUISINES[slug] ?? slug; }

function countryScore(dish: DishDocument, cuisines: string[]) { return cuisineScore(dish, cuisines); }

const CATEGORY_NEIGHBORS: Record<string, string[]> = {
  everyday: ['home_cooking', 'restaurant_style'], home_cooking: ['everyday', 'special_occasion'],
  special_occasion: ['restaurant_style', 'home_cooking'], restaurant_style: ['special_occasion', 'everyday'], custom: []
};
const CATEGORY_ALIASES: Record<string, string> = { everyday_staple:'everyday', home_classic:'home_cooking', celebration:'special_occasion', custom_dishes:'custom' };
function canonicalCategory(value?: string) { const slug = normalizeSlug(value); return CATEGORY_ALIASES[slug] ?? slug; }
function dishCategory(dish: DishDocument) { return canonicalCategory(dish.dishRegister ?? dish.dish_register ?? (dish as any).rawSourceData?.dish_register); }

export function categoryScore(dish: DishDocument, categories: string[]) {
  const selected = categories.map(canonicalCategory).filter(Boolean);
  if (!selected.length) return 0.5;
  const actual = dishCategory(dish);
  const custom = dish.isCustom === true || dish.sourceType === 'custom';
  return Math.max(...selected.map((category) => {
    if (category === 'custom') return custom ? 1 : 0;
    if (custom) return 0;
    if (category === actual) return 1;
    if ((CATEGORY_NEIGHBORS[category] ?? []).includes(actual)) return 0.5;
    return popularityScore(dish) >= 0.8 ? 0.1 : 0;
  }));
}

export function weightedPreferenceScore(dish: DishDocument, filters: DeckRecommendationFilters, freshness = 1, critical = false) {
  if (critical) return clamp(freshness, 0, 1);
  return 0.5 * categoryScore(dish, filters.selectedCategories ?? filters.dishRegisters ?? []) +
    0.4 * cuisineScore(dish, filters.cuisines ?? []) + 0.1 * clamp(freshness, 0, 1);
}

function moodScore(dish: DishDocument, moods: string[]) {
  if (moods.length === 0) return 0.5;
  const dishMoods = normalizeList(dish.mood);
  if (dishMoods.length === 0) return 0.2;
  const matched = moods.filter((mood) => dishMoods.includes(mood)).length;
  return clamp(matched / moods.length, 0, 1);
}

function dishRegisterScore(dish: DishDocument, selected: string[]) {
  if (selected.length === 0) return 0.5;
  const value = normalize(dish.dishRegister ?? dish.dish_register ?? (dish as any).rawSourceData?.dish_register);
  return selected.includes(value) ? 1.0 : 0.2;
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
  const selectedCategories = normalizeList(filters.selectedCategories ?? filters.dishRegisters);
  return {
    selectedCategories,
    dishRegisters: selectedCategories,
    includeCustomDishesFirst: filters.includeCustomDishesFirst === true,
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

function normalizeSlug(value?: string) { return (value ?? '').trim().toLowerCase().replace(/[\s-]+/g, '_'); }

function expansionLevel(reason: RecommendedDeckMeta['expansionReason'], strongCount: number): RecommendedDeckMeta['expansionLevel'] {
  if (!reason) return 'none';
  if (reason.includes('critical')) return 'critical';
  return strongCount < CRITICAL_THRESHOLD ? 'cuisine_expanded' : 'category_relaxed';
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

function getDishId(dish: DishDocument) {
  return String(dish._id ?? dish.id ?? '');
}

function getDishName(dish: DishDocument) {
  return (dish.name ?? '').trim().toLowerCase();
}
