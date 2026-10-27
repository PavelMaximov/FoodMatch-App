import crypto from 'crypto';
import { CatalogDish as DishDocument } from '../../../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { dishMatchesExclusions } from '../../../shared/ingredients/exclusionMatcher';
import { DeckRecommendationFilters } from '../../recommendations/deckRecommendationService';
export interface EffectiveDeckFilters {
  sessionId: string;
  dishRegisters: string[];
  includeCustomDishesFirst: boolean;
  customFirstUserIds: string[];
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
  usedCuisineUnionFallback: boolean;
  usedPartnerChoices: boolean;
  bothConfirmed: boolean;
  sessionMemberIds: string[];
}
export type Choice = { userId: string; filters: any; confirmed: boolean };
export function buildEffectiveFilters(
  input: any,
  userId?: string,
): EffectiveDeckFilters {
  const users: Choice[] = input.choices ?? [],
    mine = userId ? users.find((x) => x.userId === userId) : users[0],
    partner = userId ? users.find((x) => x.userId !== userId) : users[1],
    mf = mine?.filters ?? {},
    pf = partner?.filters ?? {},
    pair = (a: string[] = [], b: string[] = []) => {
      const x = norm(a),
        y = norm(b);
      if (!x.length) return { v: y, fall: false };
      if (!y.length) return { v: x, fall: false };
      const i = x.filter((z) => y.includes(z));
      return i.length
        ? { v: i, fall: false }
        : { v: norm([...x, ...y]), fall: true };
    },
    c = pair(
      mf.selectedCuisines ?? mf.cuisines,
      pf.selectedCuisines ?? pf.cuisines,
    );
  return {
    sessionId: String(input.id ?? input._id ?? ''),
    dishRegisters: pair(
      mf.selectedCategories ?? mf.dishRegisters,
      pf.selectedCategories ?? pf.dishRegisters,
    ).v,
    includeCustomDishesFirst: Boolean(
      mf.includeCustomDishesFirst || pf.includeCustomDishesFirst,
    ),
    customFirstUserIds: users
      .filter((x) => x.filters.includeCustomDishesFirst)
      .map((x) => x.userId)
      .sort(),
    cuisines: c.v,
    moods: norm([...(mf.moods ?? []), ...(pf.moods ?? [])]),
    diet: pair(mf.diet, pf.diet).v,
    exclusions: norm([...(mf.exclusions ?? []), ...(pf.exclusions ?? [])]),
    maxCookTime: minNumber(mf.maxCookTime, pf.maxCookTime),
    maxTotalTime: minNumber(mf.maxTotalTime, pf.maxTotalTime),
    minCalories: maxNumber(mf.minCalories, pf.minCalories),
    maxCalories: minNumber(mf.maxCalories, pf.maxCalories),
    calories: pair(mf.calories, pf.calories).v,
    effort: pair(mf.effort, pf.effort).v,
    ingredients: norm([...(mf.ingredients ?? []), ...(pf.ingredients ?? [])]),
    season: pair(mf.season, pf.season).v,
    usedCuisineUnionFallback: c.fall,
    usedPartnerChoices: Boolean(partner),
    bothConfirmed: Boolean(mine?.confirmed && partner?.confirmed),
    sessionMemberIds: (
      input.memberIds ??
      input.members?.map((x: any) => x.toString()) ??
      []
    )
      .slice()
      .sort(),
  };
}
export function createFiltersHash(f: EffectiveDeckFilters) {
  return crypto
    .createHash('sha1')
    .update(
      JSON.stringify({
        ...f,
        scoringVersion: 'weighted_category_cuisine_v1',
        selectedCategories: [...f.dishRegisters].sort(),
        dishRegisters: [...f.dishRegisters].sort(),
        customFirstUserIds: [...f.customFirstUserIds].sort(),
        selectedCuisines: [...f.cuisines].sort(),
        cuisines: [...f.cuisines].sort(),
        moods: [...f.moods].sort(),
        diet: [...f.diet].sort(),
        exclusions: [...f.exclusions].sort(),
      }),
    )
    .digest('hex');
}
function norm(v: string[] = []) {
  return [
    ...new Set(
      v
        .map((x) => (x ?? '').trim().toLowerCase().replace(/_/g, ' '))
        .filter((x) => x && x !== 'any'),
    ),
  ].sort();
}
export function choiceFilters(c: Choice): DeckRecommendationFilters {
  const categories = norm(
    c.filters.selectedCategories ?? c.filters.dishRegisters,
  );
  return {
    selectedCategories: categories,
    dishRegisters: categories,
    includeCustomDishesFirst: c.filters.includeCustomDishesFirst === true,
    cuisines: norm(c.filters.cuisines),
    moods: norm(c.filters.moods),
    diet: norm(c.filters.diet),
    exclusions: norm(c.filters.exclusions),
    maxCookTime: c.filters.maxCookTime,
    maxTotalTime: c.filters.maxTotalTime,
    minCalories: c.filters.minCalories,
    maxCalories: c.filters.maxCalories,
    calories: norm(c.filters.calories),
    effort: norm(c.filters.effort),
    ingredients: norm(c.filters.ingredients),
    season: norm(c.filters.season),
  };
}
export function isCustom(d: DishDocument) {
  return d.isCustom === true || d.sourceType === 'custom';
}
export function customFirst(
  all: DishDocument[],
  f: EffectiveDeckFilters,
  choices: Choice[],
  map: Map<string, string>,
) {
  const result: DishDocument[] = [];
  for (const uid of f.customFirstUserIds) {
    const owner = map.get(uid),
      cf = choiceFilters(choices.find((x) => x.userId === uid)!);
    result.push(
      ...all
        .filter(
          (d) =>
            isCustom(d) &&
            d.status === 'approved' &&
            d.createdBy?.toString() === owner &&
            !dishMatchesExclusions(d, f.exclusions),
        )
        .sort(
          (a, b) =>
            Number(norm(b.diet).some((x) => cf.diet.includes(x))) -
              Number(norm(a.diet).some((x) => cf.diet.includes(x))) ||
            a._id.toString().localeCompare(b._id.toString()),
        ),
    );
  }
  return [...new Map(result.map((x) => [x._id.toString(), x])).values()];
}

function minNumber(...values: unknown[]) {
  const numbers = values.filter(
    (x): x is number => typeof x === 'number' && Number.isFinite(x),
  );
  return numbers.length ? Math.min(...numbers) : undefined;
}
function maxNumber(...values: unknown[]) {
  const numbers = values.filter(
    (x): x is number => typeof x === 'number' && Number.isFinite(x),
  );
  return numbers.length ? Math.max(...numbers) : undefined;
}
