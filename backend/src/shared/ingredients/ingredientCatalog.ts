import { normalizeIngredientKey, normalizeIngredientText } from './ingredientNormalizer';

export type ExclusionTag =
  | 'nuts'
  | 'dairy'
  | 'gluten'
  | 'eggs'
  | 'meat'
  | 'pork'
  | 'beef'
  | 'chicken'
  | 'fish'
  | 'seafood'
  | 'spicy'
  | 'alcohol';

export type IngredientCatalogSource = 'dishes' | 'ingredients_txt' | 'manual';

export interface IngredientCatalogItem {
  id: string;
  canonicalName: string;
  displayName: string;
  aliases: string[];
  category?: string;
  exclusionTags: ExclusionTag[];
  dietTags?: string[];
  source: IngredientCatalogSource[];
  frequency?: number;
}

const TAGGED_TERMS: Array<{ canonicalName: string; aliases?: string[]; exclusionTags: ExclusionTag[] }> = [
  { canonicalName: 'pine nuts', aliases: ['pine nut', 'pinenuts'], exclusionTags: ['nuts'] },
  { canonicalName: 'peanuts', aliases: ['peanut', 'peanut butter', 'peanut oil'], exclusionTags: ['nuts'] },
  { canonicalName: 'almonds', aliases: ['almond', 'almond flour', 'almond meal', 'almond paste', 'almond butter', 'almond milk'], exclusionTags: ['nuts'] },
  { canonicalName: 'cashews', aliases: ['cashew', 'cashew nuts', 'cashew nut'], exclusionTags: ['nuts'] },
  { canonicalName: 'pistachios', aliases: ['pistachio', 'pistachio nuts'], exclusionTags: ['nuts'] },
  { canonicalName: 'hazelnuts', aliases: ['hazelnut', 'hazelnut oil', 'nutella', 'chocolate hazelnut spread'], exclusionTags: ['nuts'] },
  { canonicalName: 'walnuts', aliases: ['walnut', 'walnut oil'], exclusionTags: ['nuts'] },
  { canonicalName: 'pecans', aliases: ['pecan', 'pecan halves'], exclusionTags: ['nuts'] },
  { canonicalName: 'macadamia nuts', aliases: ['macadamia nut'], exclusionTags: ['nuts'] },
  { canonicalName: 'brazil nuts', aliases: ['brazil nut'], exclusionTags: ['nuts'] },
  { canonicalName: 'mixed nuts', exclusionTags: ['nuts'] },

  { canonicalName: 'butter', aliases: ['unsalted butter', 'salted butter', 'ghee'], exclusionTags: ['dairy'] },
  { canonicalName: 'milk', aliases: ['whole milk', 'skim milk', 'buttermilk'], exclusionTags: ['dairy'] },
  { canonicalName: 'cream', aliases: ['heavy cream', 'whipping cream', 'sour cream', 'cream cheese', 'creme fraiche', 'crème fraîche'], exclusionTags: ['dairy'] },
  { canonicalName: 'cheese', aliases: ['cheddar', 'cheddar cheese', 'mozzarella', 'fresh mozzarella', 'parmesan', 'parmesan cheese', 'pecorino', 'pecorino cheese', 'ricotta', 'ricotta cheese', 'mascarpone', 'mascarpone cheese', 'feta', 'feta cheese', 'blue cheese', 'gorgonzola', 'swiss cheese', 'gruyere', 'provolone', 'gouda', 'fontina', 'cottage cheese'], exclusionTags: ['dairy'] },
  { canonicalName: 'yogurt', aliases: ['yoghurt', 'greek yogurt', 'plain yogurt', 'natural yoghurt'], exclusionTags: ['dairy'] },
  { canonicalName: 'ice cream', aliases: ['custard', 'bechamel', 'béchamel'], exclusionTags: ['dairy'] },

  { canonicalName: 'flour', aliases: ['all purpose flour', 'wheat flour'], exclusionTags: ['gluten'] },
  { canonicalName: 'wheat', aliases: ['bulgur', 'bulgur wheat', 'wheat couscous'], exclusionTags: ['gluten'] },
  { canonicalName: 'bread', aliases: ['breadcrumbs', 'bread crumbs', 'rye bread'], exclusionTags: ['gluten'] },
  { canonicalName: 'pasta', aliases: ['spaghetti', 'penne pasta', 'lasagna sheets', 'lasagna noodles'], exclusionTags: ['gluten'] },
  { canonicalName: 'noodles', aliases: ['ramen noodles', 'egg noodles', 'wheat noodles'], exclusionTags: ['gluten'] },
  { canonicalName: 'barley', aliases: ['rye', 'couscous'], exclusionTags: ['gluten'] },
  { canonicalName: 'pizza dough', aliases: ['pizza crust'], exclusionTags: ['gluten'] },
  { canonicalName: 'wrappers', aliases: ['gyoza wrappers', 'wonton wrappers', 'egg roll wrappers'], exclusionTags: ['gluten'] },
  { canonicalName: 'pastry', aliases: ['puff pastry', 'phyllo dough'], exclusionTags: ['gluten'] },
  { canonicalName: 'soy sauce', aliases: ['teriyaki sauce'], exclusionTags: ['gluten'] },

  { canonicalName: 'eggs', aliases: ['egg', 'egg yolk', 'egg yolks', 'egg white', 'egg whites', 'hard boiled egg', 'hard-boiled egg', 'mayonnaise', 'mayo', 'aioli', 'meringue', 'hollandaise sauce'], exclusionTags: ['eggs'] },

  { canonicalName: 'beef', aliases: ['beef mince', 'ground beef', 'beef broth', 'beef stock', 'beef rump', 'ribeye steak', 'sirloin steak', 'brisket', 'veal', 'hamburger meat'], exclusionTags: ['meat', 'beef'] },
  { canonicalName: 'lamb', aliases: ['lamb mince'], exclusionTags: ['meat'] },
  { canonicalName: 'pork', aliases: ['pork mince', 'pork broth', 'pork belly', 'pork neck', 'pork shoulder', 'lard'], exclusionTags: ['meat', 'pork'] },
  { canonicalName: 'chicken', aliases: ['chicken thighs', 'chicken breast', 'chicken broth', 'chicken stock', 'chicken bouillon', 'chicken soup', 'chicken wings', 'chicken legs', 'chicken pieces'], exclusionTags: ['meat', 'chicken'] },
  { canonicalName: 'meat', aliases: ['turkey', 'duck', 'meatballs', 'meat stock', 'bone broth', 'gelatin'], exclusionTags: ['meat'] },
  { canonicalName: 'processed pork', aliases: ['bacon', 'ham', 'sausage', 'salami', 'prosciutto', 'pepperoni', 'chorizo', 'pancetta'], exclusionTags: ['meat', 'pork'] },

  { canonicalName: 'fish', aliases: ['fish sauce', 'salmon', 'tuna', 'cod', 'haddock', 'trout', 'anchovy', 'anchovies', 'mackerel', 'seabass', 'sea bass', 'tilapia', 'halibut', 'dashi', 'bonito flakes'], exclusionTags: ['fish', 'seafood'] },
  { canonicalName: 'seafood', aliases: ['shrimp', 'prawns', 'prawn', 'crab', 'crab meat', 'lobster', 'mussels', 'clams', 'oysters', 'scallops', 'squid', 'calamari', 'octopus', 'cuttlefish', 'crawfish', 'nori', 'wakame', 'seaweed'], exclusionTags: ['seafood'] },

  { canonicalName: 'chili', aliases: ['chilli', 'chile', 'chili powder', 'chili flakes', 'red pepper flakes', 'cayenne', 'jalapeno', 'jalapeño', 'habanero', 'serrano', 'hot sauce', 'sriracha', 'harissa', 'gochujang', 'sambal oelek', 'tabasco', 'red curry paste', 'green curry paste', 'curry paste', 'adjika', 'gochugaru', 'hot paprika'], exclusionTags: ['spicy'] },

  { canonicalName: 'wine', aliases: ['red wine', 'white wine', 'dry white wine', 'cooking wine', 'shaoxing wine', 'chinese rice wine', 'marsala wine'], exclusionTags: ['alcohol'] },
  { canonicalName: 'alcohol', aliases: ['beer', 'sake', 'mirin', 'rum', 'vodka', 'brandy', 'cognac', 'whiskey', 'whisky', 'bourbon', 'tequila', 'sherry', 'cooking sherry', 'marsala', 'vermouth', 'port', 'champagne', 'prosecco', 'liqueur', 'amaretto', 'cointreau', 'kahlua', 'baileys', 'limoncello', 'kirsch'], exclusionTags: ['alcohol'] }
];

const EXPLICIT_SAFE_TERMS = [
  'nutmeg', 'donut', 'doughnut', 'coconut', 'coconut milk', 'coconut cream', 'soy milk', 'rice milk', 'oat milk',
  'rice noodles', 'rice flour', 'corn flour', 'corn tortillas', 'gluten free flour', 'gluten free all purpose flour', 'gluten-free flour'
];

export const INGREDIENT_CATALOG: IngredientCatalogItem[] = [
  ...TAGGED_TERMS.map((term) => toCatalogItem(term.canonicalName, term.aliases ?? [], term.exclusionTags)),
  ...EXPLICIT_SAFE_TERMS.map((term) => toCatalogItem(term, [], []))
];

export const INGREDIENT_CATALOG_BY_KEY = buildCatalogLookup();

function toCatalogItem(canonicalName: string, aliases: string[], exclusionTags: ExclusionTag[]): IngredientCatalogItem {
  return {
    id: normalizeIngredientKey(canonicalName),
    canonicalName: normalizeIngredientText(canonicalName),
    displayName: toDisplayName(canonicalName),
    aliases: aliases.map(normalizeIngredientText),
    exclusionTags,
    dietTags: [],
    source: ['manual']
  };
}

function buildCatalogLookup() {
  const lookup = new Map<string, IngredientCatalogItem>();
  for (const item of INGREDIENT_CATALOG) {
    lookup.set(normalizeIngredientText(item.canonicalName), item);
    lookup.set(normalizeIngredientKey(item.canonicalName), item);
    for (const alias of item.aliases) {
      lookup.set(normalizeIngredientText(alias), item);
      lookup.set(normalizeIngredientKey(alias), item);
    }
  }
  return lookup;
}

function toDisplayName(value: string) {
  return normalizeIngredientText(value).replace(/\b\w/g, (letter) => letter.toUpperCase());
}
