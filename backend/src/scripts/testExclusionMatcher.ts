import { ingredientMatchesExclusions } from '../shared/ingredients/exclusionMatcher';

const shouldExclude: Record<string, string[]> = {
  no_nuts: ['pine nuts', 'pinenuts', 'peanuts', 'peanut butter', 'peanut oil', 'almond flour', 'almond milk', 'cashews', 'pistachios', 'walnut oil', 'nutella'],
  no_dairy: ['fresh mozzarella', 'parmesan', 'pecorino', 'mascarpone', 'yogurt', 'greek yogurt', 'ghee', 'sour cream', 'cream cheese', 'béchamel', 'bechamel'],
  no_gluten: ['spaghetti', 'pasta', 'pizza dough', 'lasagna sheets', 'gyoza wrappers', 'ramen noodles', 'soy sauce', 'wheat flour'],
  no_eggs: ['eggs', 'egg yolk', 'egg whites', 'mayonnaise', 'aioli', 'meringue'],
  no_meat: ['beef mince', 'lamb mince', 'pork belly', 'chicken thighs', 'chicken broth', 'bacon', 'pancetta', 'pepperoni', 'gelatin'],
  no_pork: ['pork broth', 'pork belly', 'pork neck', 'bacon', 'pancetta', 'prosciutto', 'pepperoni', 'chorizo', 'lard'],
  no_beef: ['beef mince', 'ground beef', 'beef rump', 'ribeye steak', 'beef broth', 'veal'],
  no_chicken: ['chicken', 'chicken thighs', 'chicken breast', 'chicken broth', 'chicken stock'],
  no_fish: ['salmon', 'tuna', 'fish sauce', 'anchovy', 'dashi', 'bonito flakes'],
  no_seafood: ['prawns', 'shrimp', 'crab', 'scallops', 'mussels', 'calamari', 'cuttlefish', 'squid', 'fish sauce', 'nori', 'wakame'],
  no_spicy: ['chili flakes', 'red curry paste', 'green curry paste', 'sriracha', 'harissa', 'gochujang', 'adjika', 'hot paprika'],
  no_alcohol: ['white wine', 'red wine', 'beer', 'sake', 'mirin', 'marsala wine', 'rum', 'vodka', 'brandy']
};

const shouldAllow: Record<string, string[]> = {
  no_nuts: ['nutmeg', 'donut', 'coconut', 'coconut milk'],
  no_dairy: ['coconut milk', 'almond milk', 'soy milk', 'rice milk'],
  no_gluten: ['rice noodles', 'rice flour', 'corn tortillas', 'gluten-free flour']
};

const failures: string[] = [];
for (const [exclusion, ingredients] of Object.entries(shouldExclude)) {
  for (const ingredient of ingredients) {
    if (!ingredientMatchesExclusions(ingredient, [exclusion])) failures.push(`Expected ${exclusion} to exclude "${ingredient}"`);
  }
}
for (const [exclusion, ingredients] of Object.entries(shouldAllow)) {
  for (const ingredient of ingredients) {
    if (ingredientMatchesExclusions(ingredient, [exclusion])) failures.push(`Expected ${exclusion} to allow "${ingredient}"`);
  }
}

if (failures.length > 0) {
  console.error(failures.join('\n'));
  process.exit(1);
}

console.log(`Exclusion matcher assertions passed (${Object.values(shouldExclude).flat().length + Object.values(shouldAllow).flat().length} cases).`);
