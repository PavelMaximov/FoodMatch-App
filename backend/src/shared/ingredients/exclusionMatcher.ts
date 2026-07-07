import { INGREDIENT_CATALOG_BY_KEY, ExclusionTag } from './ingredientCatalog';
import { isLikelyNoiseIngredient, normalizeIngredientKey, normalizeIngredientText, tokenizeIngredient } from './ingredientNormalizer';

export interface MatchedIngredientExclusionReason {
  ingredient: string;
  normalized: string;
  tags: string[];
  matchedExclusions: string[];
  source: string;
}

export interface DishExclusionReason {
  matched: boolean;
  reasons: MatchedIngredientExclusionReason[];
}

const EXCLUSION_KEY_TO_TAGS: Record<string, ExclusionTag[]> = {
  no_nuts: ['nuts'],
  nuts: ['nuts'],
  no_dairy: ['dairy'],
  dairy: ['dairy'],
  no_gluten: ['gluten'],
  gluten: ['gluten'],
  no_eggs: ['eggs'],
  no_egg: ['eggs'],
  eggs: ['eggs'],
  egg: ['eggs'],
  no_meat: ['meat'],
  meat: ['meat'],
  no_pork: ['pork'],
  pork: ['pork'],
  no_beef: ['beef'],
  beef: ['beef'],
  no_chicken: ['chicken'],
  chicken: ['chicken'],
  no_fish: ['fish'],
  fish: ['fish'],
  no_seafood: ['seafood'],
  seafood: ['seafood'],
  no_spicy: ['spicy'],
  spicy: ['spicy'],
  no_alcohol: ['alcohol'],
  alcohol: ['alcohol']
};

const SAFE_PHRASES = new Set([
  'nutmeg', 'donut', 'doughnut', 'coconut', 'coconut milk', 'coconut cream', 'soy milk', 'rice milk', 'oat milk',
  'rice noodles', 'rice flour', 'corn flour', 'corn tortillas', 'gluten free flour', 'gluten free all purpose flour'
]);

const PHRASE_FALLBACKS: Array<{ tags: ExclusionTag[]; phrases: string[] }> = [
  { tags: ['nuts'], phrases: ['pine nuts', 'pinenuts', 'peanut', 'peanuts', 'almond', 'almonds', 'cashew', 'cashews', 'pistachio', 'pistachios', 'hazelnut', 'hazelnuts', 'walnut', 'walnuts', 'pecan', 'pecans', 'macadamia nuts', 'brazil nuts', 'mixed nuts', 'nutella'] },
  { tags: ['dairy'], phrases: ['butter', 'milk', 'buttermilk', 'cream', 'sour cream', 'cream cheese', 'cheese', 'cheddar', 'mozzarella', 'parmesan', 'pecorino', 'ricotta', 'mascarpone', 'feta', 'gorgonzola', 'gruyere', 'provolone', 'gouda', 'fontina', 'yogurt', 'yoghurt', 'ghee', 'creme fraiche', 'cottage cheese', 'ice cream', 'custard', 'bechamel'] },
  { tags: ['gluten'], phrases: ['all purpose flour', 'wheat flour', 'wheat', 'bread', 'breadcrumbs', 'bread crumbs', 'pasta', 'spaghetti', 'lasagna sheets', 'lasagna noodles', 'ramen noodles', 'egg noodles', 'wheat noodles', 'couscous', 'bulgur', 'barley', 'rye', 'pizza dough', 'pizza crust', 'gyoza wrappers', 'wonton wrappers', 'egg roll wrappers', 'puff pastry', 'phyllo dough', 'pastry', 'soy sauce', 'teriyaki sauce'] },
  { tags: ['eggs'], phrases: ['egg', 'eggs', 'egg yolk', 'egg white', 'hard boiled egg', 'mayonnaise', 'mayo', 'aioli', 'meringue', 'hollandaise sauce'] },
  { tags: ['meat', 'beef'], phrases: ['beef', 'beef mince', 'ground beef', 'beef broth', 'beef stock', 'beef rump', 'ribeye steak', 'sirloin steak', 'brisket', 'veal', 'hamburger meat'] },
  { tags: ['meat'], phrases: ['lamb', 'lamb mince', 'turkey', 'duck', 'meatballs', 'meat stock', 'bone broth', 'gelatin'] },
  { tags: ['meat', 'pork'], phrases: ['pork', 'pork mince', 'pork broth', 'pork belly', 'pork neck', 'pork shoulder', 'bacon', 'pancetta', 'ham', 'prosciutto', 'pepperoni', 'chorizo', 'salami', 'lard', 'sausage'] },
  { tags: ['meat', 'chicken'], phrases: ['chicken', 'chicken thighs', 'chicken breast', 'chicken broth', 'chicken stock', 'chicken bouillon', 'chicken soup', 'chicken wings', 'chicken legs', 'chicken pieces'] },
  { tags: ['fish', 'seafood'], phrases: ['fish', 'fish sauce', 'salmon', 'tuna', 'cod', 'haddock', 'trout', 'anchovy', 'anchovies', 'mackerel', 'seabass', 'sea bass', 'tilapia', 'halibut', 'dashi', 'bonito flakes'] },
  { tags: ['seafood'], phrases: ['shrimp', 'prawns', 'prawn', 'crab', 'crab meat', 'lobster', 'mussels', 'clams', 'oysters', 'scallops', 'squid', 'calamari', 'octopus', 'cuttlefish', 'crawfish', 'nori', 'wakame', 'seaweed'] },
  { tags: ['spicy'], phrases: ['chili', 'chilli', 'chile', 'chili powder', 'chili flakes', 'red pepper flakes', 'cayenne', 'jalapeno', 'habanero', 'serrano', 'hot sauce', 'sriracha', 'harissa', 'gochujang', 'sambal oelek', 'tabasco', 'red curry paste', 'green curry paste', 'curry paste', 'adjika', 'gochugaru', 'hot paprika'] },
  { tags: ['alcohol'], phrases: ['wine', 'red wine', 'white wine', 'dry white wine', 'beer', 'sake', 'mirin', 'rum', 'vodka', 'brandy', 'cognac', 'whiskey', 'whisky', 'bourbon', 'tequila', 'sherry', 'marsala', 'vermouth', 'port', 'champagne', 'prosecco', 'liqueur', 'amaretto', 'cointreau', 'kahlua', 'baileys', 'limoncello', 'kirsch', 'cooking wine', 'cooking sherry', 'shaoxing wine', 'chinese rice wine'] }
];

export function dishMatchesExclusions(dish: unknown, exclusions: string[]): boolean {
  return getMatchedExclusionReason(dish, exclusions).matched;
}

export function ingredientMatchesExclusions(ingredientText: string, exclusions: string[]): boolean {
  const requestedTags = normalizeExclusionTags(exclusions);
  if (requestedTags.size === 0) return false;
  return getExclusionTagsForIngredient(ingredientText).some((tag) => requestedTags.has(tag as ExclusionTag));
}

export function getExclusionTagsForIngredient(ingredientText: string): string[] {
  const normalized = normalizeIngredientText(ingredientText);
  if (!normalized || isLikelyNoiseIngredient(normalized)) return [];

  const exactMatch = INGREDIENT_CATALOG_BY_KEY.get(normalized) ?? INGREDIENT_CATALOG_BY_KEY.get(normalizeIngredientKey(normalized));
  if (exactMatch) return exactMatch.exclusionTags;
  if (SAFE_PHRASES.has(normalized)) return [];

  const tags = new Set<ExclusionTag>();
  for (const group of PHRASE_FALLBACKS) {
    if (group.phrases.some((phrase) => containsPhrase(normalized, normalizeIngredientText(phrase)))) {
      for (const tag of group.tags) tags.add(tag);
    }
  }
  return [...tags];
}

export function getMatchedExclusionReason(dish: unknown, exclusions: string[]): DishExclusionReason {
  const requestedTags = normalizeExclusionTags(exclusions);
  if (requestedTags.size === 0) return { matched: false, reasons: [] };

  const reasons: MatchedIngredientExclusionReason[] = [];
  for (const candidate of extractDishIngredientTexts(dish)) {
    const tags = getExclusionTagsForIngredient(candidate.text);
    const matchedExclusions = tags.filter((tag) => requestedTags.has(tag as ExclusionTag));
    if (matchedExclusions.length > 0) {
      reasons.push({ ingredient: candidate.text, normalized: normalizeIngredientText(candidate.text), tags, matchedExclusions, source: candidate.source });
    }
  }

  return { matched: reasons.length > 0, reasons };
}

export function normalizeExclusionTags(exclusions: string[]): Set<ExclusionTag> {
  const tags = new Set<ExclusionTag>();
  for (const exclusion of exclusions ?? []) {
    const key = normalizeIngredientKey(exclusion);
    for (const tag of EXCLUSION_KEY_TO_TAGS[key] ?? []) tags.add(tag);
  }
  return tags;
}

export function extractDishIngredientTexts(dish: unknown): Array<{ text: string; source: string }> {
  const raw = toPlainDish(dish) as any;
  const values: Array<{ text: string; source: string }> = [];
  const push = (value: unknown, source: string) => {
    if (typeof value === 'string' && value.trim().length > 0) values.push({ text: value, source });
  };

  if (Array.isArray(raw?.sections)) {
    raw.sections.forEach((section: any, sectionIndex: number) => {
      if (!Array.isArray(section?.components)) return;
      section.components.forEach((component: any, componentIndex: number) => {
        const prefix = `sections[${sectionIndex}].components[${componentIndex}]`;
        push(component?.raw_text, `${prefix}.raw_text`);
        push(component?.ingredient?.name, `${prefix}.ingredient.name`);
        push(component?.ingredient?.display_singular, `${prefix}.ingredient.display_singular`);
        push(component?.ingredient?.display_plural, `${prefix}.ingredient.display_plural`);
      });
    });
  }

  if (Array.isArray(raw?.structuredIngredients)) {
    raw.structuredIngredients.forEach((ingredient: any, index: number) => push(ingredient?.name, `structuredIngredients[${index}].name`));
  }

  if (Array.isArray(raw?.ingredients)) {
    raw.ingredients.forEach((ingredient: unknown, index: number) => push(ingredient, `ingredients[${index}]`));
  }

  return values.filter((value, index, arr) => arr.findIndex((other) => normalizeIngredientText(other.text) === normalizeIngredientText(value.text)) === index);
}

function containsPhrase(normalizedText: string, normalizedPhrase: string): boolean {
  if (!normalizedText || !normalizedPhrase || SAFE_PHRASES.has(normalizedText)) return false;
  if (normalizedText === normalizedPhrase) return true;
  const tokens = tokenizeIngredient(normalizedText);
  const phraseTokens = tokenizeIngredient(normalizedPhrase);
  if (phraseTokens.length === 0 || tokens.length < phraseTokens.length) return false;
  for (let i = 0; i <= tokens.length - phraseTokens.length; i += 1) {
    if (phraseTokens.every((token, offset) => tokens[i + offset] === token)) return true;
  }
  return false;
}

function toPlainDish(dish: unknown): unknown {
  if (typeof (dish as any)?.toObject === 'function') return (dish as any).toObject({ virtuals: false });
  return dish;
}
