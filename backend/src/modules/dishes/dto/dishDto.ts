export interface DishNutritionDto {
  calories: number;
}

export interface DishDto {
  id: string;
  name: string;
  description: string;
  imageUrl: string;
  cuisine: string;
  type: string;
  tags: string[];
  mood: string[];
  diet: string[];
  ingredients: string[];
  ingredientCount: number;
  cookTime: number;
  totalTime: number;
  servings: string;
  qualityScore: number;
  calories: string;
  nutrition: DishNutritionDto | null;
  effort: string;
  source: string[];
  season: string[];
  popular: boolean;
  steps: Array<{ step: number; text: string }>;
}

export function toDishDto(dish: any): DishDto | null {
  if (!dish) {
    return null;
  }

  const raw = toRawDish(dish);
  if (!raw) {
    return null;
  }

  const ingredients = readIngredients(raw);
  const cookTime = firstNumber(raw.total_time_minutes, raw.cook_time_minutes, raw.cookTime);

  return {
    id: firstString(raw.id, raw.sourceId, raw._id?.toString()),
    name: asString(raw.name),
    description: asString(raw.description),
    imageUrl: firstString(raw.imageUrl, raw.thumbnail_url, raw.image_url),
    cuisine: asString(raw.cuisine),
    type: asString(raw.type),
    tags: readTags(raw.tags),
    mood: asStringList(raw.mood),
    diet: asStringList(raw.diet),
    ingredients,
    ingredientCount: ingredients.length,
    cookTime,
    totalTime: firstNumber(raw.total_time_minutes, cookTime),
    servings: firstString(raw.num_servings, raw.servings, raw.yields),
    qualityScore: firstNumber(raw.quality_score, raw.qualityScore),
    calories: firstString(raw.calories_level, raw.calories),
    nutrition: readNutrition(raw.nutrition ?? raw.rawSourceData?.nutrition),
    effort: asString(raw.effort),
    source: asStringList(raw.source),
    season: asStringList(raw.season),
    popular: typeof raw.popular === 'boolean' ? raw.popular : false,
    steps: readSteps(raw)
  };
}

export function toRawDish(dish: any) {
  return typeof dish?.toObject === 'function' ? dish.toObject({ virtuals: false }) : dish;
}

export function toPublicDishId(dish: any): string {
  const dto = toDishDto(dish);
  return dto?.id ?? '';
}

function readTags(tags: any): string[] {
  if (!Array.isArray(tags)) {
    return [];
  }

  return uniqueStrings(
    tags.map((tag) => {
      if (typeof tag === 'string') {
        return tag;
      }
      return tag?.name;
    })
  );
}

function readIngredients(rawDish: any): string[] {
  const fromSections = Array.isArray(rawDish.sections)
    ? rawDish.sections.flatMap((section: any) =>
        Array.isArray(section?.components)
          ? section.components.map((component: any) => component?.ingredient?.name)
          : []
      )
    : [];

  if (fromSections.length > 0) {
    return uniqueStrings(fromSections, false);
  }

  if (Array.isArray(rawDish.ingredients)) {
    return uniqueStrings(rawDish.ingredients, false);
  }

  return [];
}

function readNutrition(nutrition: any): DishNutritionDto | null {
  const calories = firstNumber(nutrition?.calories);
  if (calories <= 0) {
    return null;
  }

  return { calories };
}

function readSteps(rawDish: any): Array<{ step: number; text: string }> {
  if (Array.isArray(rawDish.instructions) && rawDish.instructions.length > 0) {
    return rawDish.instructions
      .map((instruction: any, index: number) => ({
        step: firstNumber(instruction?.position, index + 1),
        text: asString(instruction?.display_text)
      }))
      .filter((step: { step: number; text: string }) => step.text.length > 0);
  }

  if (Array.isArray(rawDish.steps)) {
    return rawDish.steps
      .map((step: any, index: number) => ({
        step: firstNumber(step?.step, index + 1),
        text: asString(step?.text)
      }))
      .filter((step: { step: number; text: string }) => step.text.length > 0);
  }

  return [];
}

function asStringList(value: any): string[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return uniqueStrings(value, false);
}

function uniqueStrings(values: any[], lowercase = true): string[] {
  return [...new Set(values.map((value) => {
    const normalized = asString(value);
    return lowercase ? normalized.toLowerCase() : normalized;
  }).filter(Boolean))];
}


function firstString(...values: any[]): string {
  for (const value of values) {
    const normalized = asString(value);
    if (normalized) {
      return normalized;
    }
  }

  return '';
}

function firstNumber(...values: any[]): number {
  for (const value of values) {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return Math.max(0, Math.trunc(value));
    }

    if (typeof value === 'string' && value.trim()) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) {
        return Math.max(0, Math.trunc(parsed));
      }
    }
  }

  return 0;
}

function asString(value: any): string {
  if (value === null || value === undefined) {
    return '';
  }

  return String(value).trim();
}
