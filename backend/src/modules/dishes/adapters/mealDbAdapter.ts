export interface NormalizedDishPayload {
  sourceType: 'mealdb';
  sourceId: string;
  title: string;
  description?: string;
  imageUrl?: string;
  tags: string[];
  cuisine?: string;
  ingredients: string[];
  steps: string[];
  rawSourceData: Record<string, unknown>;
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

  const instructions = meal.strInstructions?.split(/\r?\n|\./).map((step) => step.trim()).filter(Boolean) ?? [];
  const tags = meal.strTags ? meal.strTags.split(',').map((tag) => tag.trim()).filter(Boolean) : [];

  return {
    sourceType: 'mealdb',
    sourceId: meal.idMeal ?? '',
    title: meal.strMeal ?? 'Untitled dish',
    description: meal.strCategory ?? undefined,
    imageUrl: meal.strMealThumb ?? undefined,
    tags,
    cuisine: meal.strArea ?? undefined,
    ingredients,
    steps: instructions,
    rawSourceData: meal
  };
}
