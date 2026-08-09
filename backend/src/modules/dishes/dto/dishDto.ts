export const DISH_DTO_SELECT = [
  '_id',
  'id',
  'sourceId',
  'sourceType',
  'name',
  'description',
  'imageUrl',
  'imagePublicId',
  'cuisine',
  'type',
  'tags',
  'mood',
  'dishRegister',
  'dish_register',
  'spiceLevel',
  'spice_level',
  'diet',
  'ingredients',
  'ingredientCount',
  'cookTime',
  'prep_time_minutes',
  'cook_time_minutes',
  'totalTime',
  'total_time_minutes',
  'total_time_tier',
  'servings',
  'num_servings',
  'yields',
  'qualityScore',
  'quality_score',
  'calories',
  'calories_level',
  'effort',
  'source',
  'season',
  'popular',
  'steps',
  'instructions',
  'sections',
  'nutrition',
  'rawSourceData',
  'createdBy',
  'coupleId',
  'visibility',
  'status',
  'isCustom',
  'structuredIngredients',
  'createdAt',
  'updatedAt'
].join(' ');

export interface DishNutritionDto {
  calories: number;
}

export interface DishDto {
  id: string;
  name: string;
  description: string;
  imageUrl: string;
  imagePublicId?: string;
  cuisine: string;
  type: string;
  tags: string[];
  mood: string[];
  dishRegister: string;
  spiceLevel: string;
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
  ingredientSections?: IngredientSectionDto[];
  isCustom: boolean;
}

export interface IngredientSectionDto {
  name: string;
  position: number;
  components: Array<{
    position: number;
    name: string;
    displayName: string;
    rawText: string | null;
    extraComment: string | null;
    measurements: Array<{ quantity: string | number | null; unit: string | null }>;
  }>;
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
  const cookTime = firstNumber(raw.cookTime, raw.cook_time_minutes, raw.total_time_minutes);
  const totalTime = firstNumber(
    raw.totalTime,
    raw.total_time_minutes,
    firstNumber(raw.prep_time_minutes) + firstNumber(raw.cook_time_minutes),
    cookTime,
  );

  return {
    id: firstString(raw.id, raw.sourceId, raw._id?.toString()),
    name: asString(raw.name),
    description: asString(raw.description),
    imageUrl: firstString(raw.imageUrl, raw.thumbnail_url, raw.image_url),
    imagePublicId: firstString(raw.imagePublicId),
    cuisine: asString(raw.cuisine),
    type: asString(raw.type),
    tags: readTags(raw.tags),
    mood: asStringList(raw.mood),
    dishRegister: firstString(raw.dishRegister, raw.dish_register, raw.rawSourceData?.dish_register),
    spiceLevel: firstString(raw.spiceLevel, raw.spice_level, raw.rawSourceData?.spice_level),
    diet: asStringList(raw.diet),
    ingredients,
    ingredientCount: firstNumber(raw.ingredientCount, ingredients.length),
    cookTime,
    totalTime,
    servings: firstString(raw.num_servings, raw.servings, raw.yields),
    qualityScore: firstNumber(raw.quality_score, raw.qualityScore),
    calories: firstString(raw.calories_level, raw.calories),
    nutrition: readNutrition(raw.nutrition ?? raw.rawSourceData?.nutrition),
    effort: asString(raw.effort),
    source: asStringList(raw.source),
    season: asStringList(raw.season),
    popular: typeof raw.popular === 'boolean' ? raw.popular : false,
    steps: readSteps(raw),
    ingredientSections: readIngredientSections(raw),
    isCustom: raw.isCustom === true
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
          ? section.components.map((component: any) => firstString(component?.ingredient?.name, component?.name))
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

function readIngredientSections(rawDish: any): IngredientSectionDto[] | undefined {
  if (!Array.isArray(rawDish.sections) || rawDish.sections.length === 0) {
    return undefined;
  }

  const sections = rawDish.sections.map((section: any, sectionIndex: number) => ({
    name: asString(section?.name),
    position: firstNumber(section?.position, sectionIndex),
    components: Array.isArray(section?.components)
      ? section.components.map((component: any, componentIndex: number) => {
          const ingredient = component?.ingredient ?? {};
          const name = firstString(component?.name, ingredient?.name);
          return {
            position: firstNumber(component?.position, componentIndex),
            name,
            displayName: firstString(
              component?.displayName,
              ingredient?.display_singular,
              ingredient?.display_plural,
              name,
            ),
            rawText: nullableString(component?.raw_text ?? component?.rawText),
            extraComment: nullableString(component?.extra_comment ?? component?.extraComment),
            measurements: Array.isArray(component?.measurements)
              ? component.measurements.map((measurement: any) => ({
                  quantity: readMeasurementQuantity(measurement?.quantity),
                  unit: nullableString(readMeasurementUnit(measurement?.unit)),
                }))
              : [],
          };
        }).filter((component: { name: string }) => component.name.length > 0)
      : [],
  })).filter((section: IngredientSectionDto) => section.components.length > 0);

  return sections.length > 0 ? sections : undefined;
}

function readMeasurementQuantity(value: any): string | number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  return nullableString(value);
}

function readMeasurementUnit(value: any): string {
  if (typeof value === 'string') return value.trim();
  return firstString(value?.abbreviation, value?.display_singular, value?.name);
}

function nullableString(value: any): string | null {
  const result = asString(value);
  return result || null;
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
