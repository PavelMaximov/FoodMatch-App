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
    name: rawDish.name ?? '',
    description: rawDish.description ?? '',
    imageUrl: rawDish.imageUrl ?? '',
    cuisine: rawDish.cuisine ?? '',
    type: rawDish.type ?? '',
    mood: Array.isArray(rawDish.mood) ? rawDish.mood : [],
    diet: Array.isArray(rawDish.diet) ? rawDish.diet : [],
    ingredients: Array.isArray(rawDish.ingredients) ? rawDish.ingredients : [],
    cookTime: typeof rawDish.cookTime === 'number' ? rawDish.cookTime : 0,
    calories: rawDish.calories ?? '',
    effort: rawDish.effort ?? '',
    source: Array.isArray(rawDish.source) && rawDish.source.length > 0 ? rawDish.source : [rawDish.sourceType ?? 'custom'],
    servings: rawDish.servings ?? '',
    season: Array.isArray(rawDish.season) ? rawDish.season : [],
    popular: typeof rawDish.popular === 'boolean' ? rawDish.popular : false,
    steps: Array.isArray(rawDish.steps)
      ? rawDish.steps.map((step: any, index: number) => ({
          step: typeof step.step === 'number' ? step.step : index + 1,
          text: typeof step.text === 'string' ? step.text : String(step ?? '')
        }))
      : []
  };
}

export function toRawDish(dish: any) {
  return typeof dish?.toObject === 'function' ? dish.toObject({ virtuals: true }) : dish;
}

export function toPublicDishId(dish: any) {
  const rawDish = toRawDish(dish);

  if (typeof rawDish.sourceId === 'string' && rawDish.sourceId.length > 0) {
    return rawDish.sourceId;
  }

  if (typeof rawDish.id === 'string' && rawDish.id.length > 0) {
    return rawDish.id;
  }

  return rawDish._id?.toString() ?? '';
}
