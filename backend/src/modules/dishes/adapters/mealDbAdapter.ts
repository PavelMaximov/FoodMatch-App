export interface NormalizedDishPayload {
  sourceType: 'mealdb';
  sourceId: string;
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
  rawSourceData: Record<string, unknown>;
}

function parseCookTime(strYoutube: string | null | undefined): number {
  if (!strYoutube) return 0;
  return 30;
}

export function adaptMealDbMeal(meal: Record<string, string | null>): NormalizedDishPayload {
  const ingredients: string[] = [];

  for (let i = 1; i <= 20; i += 1) {
    const ingredient = meal[`strIngredient${i}`]?.trim();
    const measure = meal[`strMeasure${i}`]?.trim();
    if (ingredient) {
      ingredients.push(measure ? `${ingredient} - ${measure}` : ingredient);
    }
  }

  const stepTexts = meal.strInstructions
    ?.split(/\r?\n|\./)
    .map((step) => step.trim())
    .filter(Boolean) ?? [];

  const steps = stepTexts.map((text, index) => ({ step: index + 1, text }));

  return {
    sourceType: 'mealdb',
    sourceId: meal.idMeal ?? '',
    name: meal.strMeal?.trim() || 'Unknown dish',
    description: meal.strInstructions?.trim() || meal.strCategory?.trim() || '',
    imageUrl: meal.strMealThumb?.trim() || '',
    cuisine: meal.strArea?.trim() || '',
    type: meal.strCategory?.trim() || '',
    mood: [],
    diet: [],
    ingredients,
    cookTime: parseCookTime(meal.strYoutube),
    calories: '',
    effort: '',
    source: ['mealdb'],
    servings: '',
    season: [],
    popular: false,
    steps,
    rawSourceData: meal
  };
}
