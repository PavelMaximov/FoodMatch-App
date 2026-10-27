import {
  CatalogDish as DishDocument,
  postgresDishes,
} from '../../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { loadDishesById } from '../../../shared/db/dishIdMapping';
import { dishMatchesExclusions } from '../../../shared/ingredients/exclusionMatcher';
import { normalizeFilterList } from '../../filters/services/lastFilterPresetService';
import {
  buildRecommendedDeck,
  DeckRecommendationHistoryEntry,
  RecommendedDeckMeta,
} from '../../recommendations/deckRecommendationService';
const MAX_DECK_SIZE = 30;
export type SoloFilterInput = {
  dishRegisters?: string[];
  includeCustomDishesFirst?: boolean;
  cuisines?: string[];
  moods?: string[];
  diet?: string[];
  exclusions?: string[];
  maxCookTime?: number;
  maxTotalTime?: number;
  minCalories?: number;
  maxCalories?: number;
  calories?: string[];
  effort?: string[];
  ingredients?: string[];
  season?: string[];
};
export type NormalizedSoloFilter = {
  dishRegisters: string[];
  includeCustomDishesFirst: boolean;
  cuisines: string[];
  moods: string[];
  diet: string[];
  exclusions: string[];
  maxCookTime?: number;
  maxTotalTime?: number;
  minCalories?: number;
  maxCalories?: number;
  calories: string[];
  effort: string[];
  ingredients: string[];
  season: string[];
};
type DeckBuildResult = { dishes: DishDocument[]; meta: RecommendedDeckMeta };
export class SoloDeckService {
  normalizeFilter(f: SoloFilterInput): NormalizedSoloFilter {
    return {
      dishRegisters: normalizeFilterList(f.dishRegisters),
      includeCustomDishesFirst: f.includeCustomDishesFirst === true,
      cuisines: normalizeFilterList(f.cuisines),
      moods: normalizeFilterList(f.moods),
      diet: normalizeFilterList(f.diet),
      exclusions: normalizeFilterList(f.exclusions),
      maxCookTime: number(f.maxCookTime),
      maxTotalTime: number(f.maxTotalTime),
      minCalories: number(f.minCalories),
      maxCalories: number(f.maxCalories),
      calories: normalizeFilterList(f.calories),
      effort: normalizeFilterList(f.effort),
      ingredients: normalizeFilterList(f.ingredients),
      season: normalizeFilterList(f.season),
    };
  }
  async buildDeck(
    userId: string,
    filter: NormalizedSoloFilter,
    excludeDishIds = new Set<string>(),
    recentlySeenDishIds = new Set<string>(),
  ): Promise<DeckBuildResult> {
    const runtime = userId;
    const all = await postgresDishes.listLightweight(userId),
      history = await this.loadUserHistory(userId);
    const result = buildRecommendedDeck({
      userId,
      dishes: all,
      filters: filter,
      userHistory: history,
      recentlySeenDishIds,
      excludedDishIds: excludeDishIds,
      deckSize: MAX_DECK_SIZE,
      mode: 'solo',
    });
    if (!filter.includeCustomDishesFirst) {
      logDeckOrder('solo', false, [], result.dishes);
      return result;
    }
    const custom = all
      .filter(
        (d) =>
          isUsableOwnedCustomDish(d, runtime) &&
          !excludeDishIds.has(d._id.toString()) &&
          !dishMatchesExclusions(d, filter.exclusions) &&
          matchesCustomDiet(d, filter.diet),
      )
      .sort((a, b) => compareCustomByPreferences(a, b, filter));
    const customIds = new Set(custom.map((d) => d._id.toString())),
      prefix = custom.slice(0, MAX_DECK_SIZE),
      tail = result.dishes
        .filter((d) => !customIds.has(d._id.toString()))
        .slice(0, MAX_DECK_SIZE - prefix.length);
    logDeckOrder('solo', true, prefix, tail);
    return {
      ...result,
      dishes: [...prefix, ...tail],
      meta: {
        ...result.meta,
        finalCount: prefix.length + tail.length,
        customIncludedCount: prefix.length,
      },
    };
  }
  async loadUserHistory(
    userId: string,
  ): Promise<DeckRecommendationHistoryEntry[]> {
    const [solo, pair] = await Promise.all([
        domainRepositories.soloSessions.findResumable(userId),
        domainRepositories.coupleSessions.findActiveForUser(userId),
      ]),
      rows = [] as any[];
    if (solo)
      rows.push(
        ...(await domainRepositories.swipes.listForUserSession(
          userId,
          solo.id,
          'solo',
        )),
      );
    if (pair)
      rows.push(
        ...(await domainRepositories.swipes.listForUserSession(
          userId,
          pair.id,
          'paired',
        )),
      );
    const dishes = await loadDishesById(rows.map((r) => r.dishId));
    return rows
      .map((r) =>
        dishes.has(r.dishId)
          ? { dish: dishes.get(r.dishId)!, direction: r.direction }
          : null,
      )
      .filter((x): x is DeckRecommendationHistoryEntry => !!x);
  }
}

export function isUsableOwnedCustomDish(dish: DishDocument, userId: string) {
  return (
    (dish.isCustom === true || dish.sourceType === 'custom') &&
    dish.status === 'approved' &&
    dish.createdBy?.toString() === userId
  );
}

function matchesCustomDiet(dish: DishDocument, diet: string[]) {
  const values = new Set(
    (dish.diet ?? []).map((value: string) => value.trim().toLowerCase()),
  );
  if (diet.includes('vegan')) return values.has('vegan');
  if (diet.includes('vegetarian'))
    return values.has('vegetarian') || values.has('vegan');
  return true;
}

function compareCustomByPreferences(
  a: DishDocument,
  b: DishDocument,
  filters: NormalizedSoloFilter,
) {
  const registerDelta =
    preferenceMatch(
      b.dishRegister ?? (b as any).dish_register,
      filters.dishRegisters,
    ) -
    preferenceMatch(
      a.dishRegister ?? (a as any).dish_register,
      filters.dishRegisters,
    );
  if (registerDelta !== 0) return registerDelta;
  const cuisineDelta =
    preferenceMatch(b.cuisine, filters.cuisines) -
    preferenceMatch(a.cuisine, filters.cuisines);
  if (cuisineDelta !== 0) return cuisineDelta;
  const dateDelta = customTimestamp(b) - customTimestamp(a);
  return dateDelta || a._id.toString().localeCompare(b._id.toString());
}

function preferenceMatch(value: string | undefined, selected: string[]) {
  return selected.includes(
    (value ?? '').trim().toLowerCase().replace(/_/g, ' '),
  )
    ? 1
    : 0;
}
function customTimestamp(dish: DishDocument) {
  return ((dish as any).updatedAt ?? dish.createdAt)?.getTime?.() ?? 0;
}
function logDeckOrder(
  mode: 'solo',
  customFirst: boolean,
  prefix: DishDocument[],
  tail: DishDocument[],
) {
  const final = [...prefix, ...tail];
  console.log(
    `[DeckOrder] mode=${mode} customFirst=${customFirst} customPrefixCount=${prefix.length} tailCount=${tail.length} finalCount=${final.length}`,
  );
  console.log(
    `[DeckOrder] firstIds=${final
      .slice(0, 8)
      .map((dish) => dish._id.toString())
      .join(',')}`,
  );
  console.log('[DeckOrder] noRandomShuffle=true');
}

function number(value: unknown) {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.max(0, Math.trunc(value))
    : undefined;
}
