import { Types } from 'mongoose';

export interface DishDto {
  id: string;
  name: string;
  description: string;
  imageUrl: string;
  cuisine: string;
  type: string;
  mood: string[];
  diet: string[];
  ingredients: string[];
  cookTime: number;
  calories: string;
  effort: string;
  source: string[];
  servings: string;
  season: string[];
  popular: boolean;
  steps: Array<{ step: number; text: string }>;
}

export function toDishDto(dish: any): DishDto {
  const rawDish = toRawDish(dish);

  return {
    id: toPublicDishId(rawDish),
    name: asString(rawDish.name).value,
    description: asString(rawDish.description).value,
    imageUrl: firstString(rawDish.imageUrl, rawDish.image_url, rawDish.image, rawDish.thumbnail, rawDish.photoUrl, rawDish.photo_url),
    cuisine: asString(rawDish.cuisine).value,
    type: asString(rawDish.type).value,
    mood: asStringList(rawDish.mood),
    diet: asStringList(rawDish.diet),
    ingredients: readIngredients(rawDish),
    cookTime: firstNumber(rawDish.cook_time_minutes, rawDish.cookTime),
    calories: asString(rawDish.calories).value,
    effort: asString(rawDish.effort).value,
    source: readSource(rawDish),
    servings: firstString(rawDish.num_servings, rawDish.servings),
    season: asStringList(rawDish.season),
    popular: typeof rawDish.popular === 'boolean' ? rawDish.popular : false,
    steps: readSteps(rawDish)
  };
}

export function toRawDish(dish: any) {
  return typeof dish?.toObject === 'function' ? dish.toObject({ virtuals: false }) : dish;
}

export function toPublicDishId(dish: any) {
  const rawDish = toRawDish(dish);
  const sourceId = asString(rawDish.sourceId);
  if (sourceId.isNotEmpty) {
    return sourceId.value;
  }

  const publicId = firstStringValue(rawDish.publicId, rawDish.public_id, rawDish.dishId, rawDish.dish_id, rawDish.id);
  if (publicId && !Types.ObjectId.isValid(publicId)) {
    return publicId;
  }

  return rawDish._id?.toString() ?? publicId ?? '';
}

function readIngredients(rawDish: any): string[] {
  const sectionIngredients = readSectionIngredientNames(rawDish.sections);
  if (sectionIngredients.length > 0) {
    return sectionIngredients;
  }

  const structuredIngredients = readStructuredIngredientNames(rawDish.structuredIngredients);
  if (structuredIngredients.length > 0) {
    return structuredIngredients;
  }

  return asStringList(rawDish.ingredients);
}

function readSectionIngredientNames(sections: any): string[] {
  if (!Array.isArray(sections)) {
    return [];
  }

  const names: string[] = [];
  for (const section of sections) {
    const components = Array.isArray(section?.components) ? section.components : [];
    for (const component of components) {
      const name = firstStringValue(
        component?.ingredient?.name,
        component?.ingredient_name,
        component?.name
      );
      if (name) {
        names.push(name);
      }
    }
  }

  return uniqueStrings(names);
}

function readStructuredIngredientNames(ingredients: any): string[] {
  if (!Array.isArray(ingredients)) {
    return [];
  }

  return uniqueStrings(
    ingredients
      .map((ingredient) => firstStringValue(ingredient?.name, ingredient))
      .filter((name): name is string => Boolean(name))
  );
}

function readSteps(rawDish: any): Array<{ step: number; text: string }> {
  const instructionSteps = normalizeSteps(rawDish.instructions);
  if (instructionSteps.length > 0) {
    return instructionSteps;
  }

  return normalizeSteps(rawDish.steps);
}

function normalizeSteps(rawSteps: any): Array<{ step: number; text: string }> {
  if (!Array.isArray(rawSteps)) {
    return [];
  }

  return rawSteps
    .map((rawStep, index) => {
      if (typeof rawStep === 'string') {
        return { step: index + 1, text: rawStep.trim() };
      }

      const text = firstStringValue(rawStep?.text, rawStep?.instruction, rawStep?.description, rawStep?.title) ?? '';
      const stepNumber = firstNumber(rawStep?.step, rawStep?.order, rawStep?.number, index + 1);
      return { step: stepNumber, text };
    })
    .filter((step) => step.text.length > 0);
}

function readSource(rawDish: any): string[] {
  const source = asStringList(rawDish.source);
  if (source.length > 0) {
    return source;
  }

  const sourceType = asString(rawDish.sourceType);
  return sourceType.isNotEmpty ? [sourceType.value] : [];
}

function asStringList(value: any): string[] {
  if (Array.isArray(value)) {
    return value
      .map((item) => asString(item).value)
      .filter((item) => item.length > 0);
  }

  const stringValue = asString(value).value;
  return stringValue.length > 0 ? [stringValue] : [];
}

function uniqueStrings(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter((value) => value.length > 0))];
}

function firstString(...values: any[]): string {
  return firstStringValue(...values) ?? '';
}

function firstStringValue(...values: any[]): string | undefined {
  for (const value of values) {
    const stringValue = asString(value).value;
    if (stringValue.length > 0) {
      return stringValue;
    }
  }

  return undefined;
}

function firstNumber(...values: any[]): number {
  for (const value of values) {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return Math.max(0, Math.trunc(value));
    }

    if (typeof value === 'string' && value.trim().length > 0) {
      const parsed = Number(value.trim());
      if (Number.isFinite(parsed)) {
        return Math.max(0, Math.trunc(parsed));
      }
    }
  }

  return 0;
}

function asString(value: any): { value: string; isNotEmpty: boolean } {
  if (value === null || value === undefined) {
    return { value: '', isNotEmpty: false };
  }

  const stringValue = String(value).trim();
  return { value: stringValue, isNotEmpty: stringValue.length > 0 };
}
