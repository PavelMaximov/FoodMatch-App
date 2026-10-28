export type CoupleFilterStatePayload = {
  includeCustomDishesFirst?: boolean;
  selectedCategories?: string[];
  dishRegisters?: string[];
  category?: string;
  selectedCuisines?: string[];
  cuisines?: string[];
  cuisine?: string | string[];
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
  choices?: CoupleFilterStatePayload;
  filter?: CoupleFilterStatePayload;
  filters?: CoupleFilterStatePayload;
};
const list = (v?: string[]) => [
  ...new Set(
    (Array.isArray(v) ? v : [])
      .map((x) => (x ?? '').trim().toLowerCase())
      .filter(Boolean),
  ),
];
export function normalizeCoupleFilterStatePayload(p: CoupleFilterStatePayload) {
  const s = p.choices ?? p.filter ?? p.filters ?? p,
    categories = list(
      s.selectedCategories ??
        s.dishRegisters ??
        (s.category ? [s.category] : []),
    ),
    cuisines = list(
      s.selectedCuisines ??
        s.cuisines ??
        (typeof s.cuisine === 'string' ? [s.cuisine] : s.cuisine),
    );
  return {
    includeCustomDishesFirst: s.includeCustomDishesFirst === true,
    selectedCategories: categories,
    dishRegisters: categories,
    selectedCuisines: cuisines,
    cuisines,
    moods: list(s.moods),
    diet: list(s.diet),
    exclusions: list(s.exclusions),
    maxCookTime: s.maxCookTime,
    maxTotalTime: s.maxTotalTime,
    minCalories: s.minCalories,
    maxCalories: s.maxCalories,
    calories: list(s.calories),
    effort: list(s.effort),
    ingredients: list(s.ingredients),
    season: list(s.season),
  };
}
