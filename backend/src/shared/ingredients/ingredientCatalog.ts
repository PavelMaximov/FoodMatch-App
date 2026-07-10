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
  { canonicalName: 'peanuts', aliases: ['peanut', 'peanut butter', 'peanut oil', 'peanut butter chips'], exclusionTags: ['nuts'] },
  { canonicalName: 'almonds', aliases: ['almond', 'almond flour', 'almond meal', 'almond paste', 'almond butter', 'almond milk', 'vanilla almond milk'], exclusionTags: ['nuts'] },
  { canonicalName: 'cashews', aliases: ['cashew', 'cashew nuts', 'cashew nut'], exclusionTags: ['nuts'] },
  { canonicalName: 'pistachios', aliases: ['pistachio', 'pistachio nuts'], exclusionTags: ['nuts'] },
  { canonicalName: 'hazelnuts', aliases: ['hazelnut', 'hazelnut oil', 'nutella', 'chocolate hazelnut spread'], exclusionTags: ['nuts'] },
  { canonicalName: 'walnuts', aliases: ['walnut', 'walnut oil'], exclusionTags: ['nuts'] },
  { canonicalName: 'pecans', aliases: ['pecan', 'pecan halves'], exclusionTags: ['nuts'] },
  { canonicalName: 'macadamia nuts', aliases: ['macadamia nut'], exclusionTags: ['nuts'] },
  { canonicalName: 'brazil nuts', aliases: ['brazil nut'], exclusionTags: ['nuts'] },
  { canonicalName: 'mixed nuts', aliases: ['nut butter'], exclusionTags: ['nuts'] },

  { canonicalName: 'butter', aliases: ['unsalted butter', 'salted butter', 'clarified butter', 'ghee'], exclusionTags: ['dairy'] },
  { canonicalName: 'milk', aliases: ['whole milk', 'skim milk', 'buttermilk', 'condensed milk', 'evaporated milk', 'warm milk'], exclusionTags: ['dairy'] },
  { canonicalName: 'cream', aliases: ['heavy cream', 'whipping cream', 'whipped cream', 'double cream', 'sour cream', 'cream cheese', 'creme fraiche', 'crème fraîche'], exclusionTags: ['dairy'] },
  { canonicalName: 'cheese', aliases: ['cheddar', 'cheddar cheese', 'mozzarella', 'fresh mozzarella', 'parmesan', 'parmesan cheese', 'pecorino', 'pecorino cheese', 'ricotta', 'ricotta cheese', 'mascarpone', 'mascarpone cheese', 'feta', 'feta cheese', 'blue cheese', 'gorgonzola', 'swiss cheese', 'gruyere', 'provolone', 'gouda', 'fontina', 'cottage cheese', 'farmers cheese', "farmer's cheese", 'white cheese', 'blue cheese dip', 'gruyere cheese', 'gruyere or cheddar', 'bryndza cheese', 'emmental cheese', 'kasar cheese'], exclusionTags: ['dairy'] },
  { canonicalName: 'yogurt', aliases: ['yoghurt', 'greek yogurt', 'plain yogurt', 'natural yoghurt', 'garlic yogurt'], exclusionTags: ['dairy'] },
  { canonicalName: 'ice cream', aliases: ['custard', 'bechamel', 'béchamel'], exclusionTags: ['dairy'] },

  { canonicalName: 'flour', aliases: ['all purpose flour', 'wheat flour', 'bread flour'], exclusionTags: ['gluten'] },
  { canonicalName: 'wheat', aliases: ['bulgur', 'bulgur wheat', 'fine bulgur', 'wheat couscous'], exclusionTags: ['gluten'] },
  { canonicalName: 'bread', aliases: ['breadcrumbs', 'bread crumbs', 'fine breadcrumbs', 'rye bread', 'white sandwich bread', 'stale bread', 'stale bread rolls', 'sourdough bread', 'white bread', 'white toast bread', 'rustic bread'], exclusionTags: ['gluten'] },
  { canonicalName: 'pasta', aliases: ['spaghetti', 'penne pasta', 'lasagna sheets', 'lasagna noodles', 'small pasta', 'trofie pasta'], exclusionTags: ['gluten'] },
  { canonicalName: 'noodles', aliases: ['ramen noodles', 'egg noodles', 'wheat noodles'], exclusionTags: ['gluten'] },
  { canonicalName: 'barley', aliases: ['rye', 'couscous', 'pearl barley', 'rye sour base'], exclusionTags: ['gluten'] },
  { canonicalName: 'pizza dough', aliases: ['pizza crust'], exclusionTags: ['gluten'] },
  { canonicalName: 'wrappers', aliases: ['gyoza wrappers', 'wonton wrappers', 'egg roll wrappers'], exclusionTags: ['gluten'] },
  { canonicalName: 'pastry', aliases: ['puff pastry', 'phyllo dough', 'filo pastry', 'shortcrust pastry', 'pie pastry', 'puff pastry or layered dough'], exclusionTags: ['gluten'] },
  { canonicalName: 'soy sauce', aliases: ['teriyaki sauce'], exclusionTags: ['gluten'] },

  { canonicalName: 'eggs', aliases: ['egg', 'egg yolk', 'egg yolks', 'egg white', 'egg whites', 'hard boiled egg', 'hard-boiled egg', 'mayonnaise', 'mayo', 'aioli', 'meringue', 'hollandaise sauce'], exclusionTags: ['eggs'] },

  { canonicalName: 'beef', aliases: ['beef mince', 'ground beef', 'beef broth', 'beef stock', 'beef rump', 'beef sirloin', 'beef chuck', 'beef on the bone', 'beef bones', 'ribeye steak', 'sirloin steak', 'brisket', 'veal', 'veal cutlet', 'hamburger meat'], exclusionTags: ['meat', 'beef'] },
  { canonicalName: 'lamb', aliases: ['lamb mince', 'lamb shoulder', 'lamb or chicken'], exclusionTags: ['meat'] },
  { canonicalName: 'pork', aliases: ['pork mince', 'pork broth', 'pork belly', 'pork neck', 'pork shoulder', 'pork loin cutlet', 'pork ribs', 'pork sausage', 'lard'], exclusionTags: ['meat', 'pork'] },
  { canonicalName: 'chicken', aliases: ['chicken thighs', 'chicken breast', 'chicken broth', 'chicken stock', 'chicken bouillon', 'chicken soup', 'chicken wings', 'chicken legs', 'chicken pieces', 'shredded chicken', 'whole chicken or legs'], exclusionTags: ['meat', 'chicken'] },
  { canonicalName: 'meat', aliases: ['turkey', 'duck', 'meatballs', 'meat stock', 'bone broth', 'gelatin'], exclusionTags: ['meat'] },
  { canonicalName: 'processed pork', aliases: ['bacon', 'streaky bacon', 'smoked bacon', 'canadian bacon', 'bacon lardons', 'smoked bacon lardons', 'ham', 'cooked ham', 'smoked ham hock', 'sausage', 'bologna sausage', 'smoked sausage', 'white sausage', 'salami', 'prosciutto', 'pepperoni', 'chorizo', 'pancetta'], exclusionTags: ['meat', 'pork'] },

  { canonicalName: 'fish', aliases: ['fish sauce', 'fish stock', 'mixed fish', 'mixed white fish', 'white fish', 'salmon', 'salmon fillet', 'salmon fillets', 'tuna', 'tuna in oil', 'canned tuna in oil', 'cod', 'cod fillet', 'haddock', 'trout', 'whole trout', 'anchovy', 'anchovies', 'mackerel', 'seabass', 'sea bass', 'tilapia', 'halibut', 'dashi', 'bonito flakes', 'red salmon caviar'], exclusionTags: ['fish', 'seafood'] },
  { canonicalName: 'seafood', aliases: ['shrimp', 'prawns', 'prawn', 'crab', 'crab meat', 'lobster', 'mussels', 'clams', 'oysters', 'scallops', 'large scallops', 'squid', 'squid ink', 'calamari', 'octopus', 'cooked octopus', 'cuttlefish', 'cuttlefish or squid', 'crawfish', 'nori', 'wakame', 'seaweed'], exclusionTags: ['seafood'] },

  { canonicalName: 'chili', aliases: ['chilli', 'chile', 'chili powder', 'chili flakes', 'red pepper flakes', 'cayenne', 'jalapeno', 'jalapeño', 'habanero', 'serrano', 'hot sauce', 'sriracha', 'harissa', 'gochujang', 'sambal oelek', 'tabasco', 'red curry paste', 'green curry paste', 'curry paste', 'adjika', 'gochugaru', 'hot paprika', 'chili paste'], exclusionTags: ['spicy'] },

  { canonicalName: 'wine', aliases: ['red wine', 'white wine', 'dry white wine', 'cooking wine', 'shaoxing wine', 'chinese rice wine', 'marsala wine', 'rice wine', 'sherry wine'], exclusionTags: ['alcohol'] },
  { canonicalName: 'alcohol', aliases: ['beer', 'sake', 'mirin', 'rum', 'vodka', 'brandy', 'cognac', 'whiskey', 'whisky', 'bourbon', 'tequila', 'sherry', 'cooking sherry', 'marsala', 'vermouth', 'port', 'champagne', 'prosecco', 'liqueur', 'amaretto', 'cointreau', 'kahlua', 'baileys', 'limoncello', 'kirsch', 'chinese rice wine'], exclusionTags: ['alcohol'] }
];

const EXPLICIT_SAFE_TERMS = [
  'nutmeg', 'donut', 'doughnut', 'coconut', 'coconut milk', 'light coconut milk', 'full coconut milk', 'coconut cream',
  'cream of coconut', 'soy milk', 'vanilla soy milk', 'rice milk', 'oat milk', 'soy yogurt', 'vegan butter', 'cocoa butter',
  'coconut butter', 'apple butter', 'pumpkin butter', 'butter beans', 'butter lettuce', 'butter lettuce leaves', 'cream of tartar',
  'rice noodles', 'rice flour', 'corn flour', 'corn tortillas', 'gluten free flour', 'gluten free all purpose flour',
  'gluten-free flour', 'gluten free soy sauce', 'tamari', 'vinegar', 'wine vinegar', 'red wine vinegar', 'white wine vinegar',
  'sherry vinegar', 'rice wine vinegar', 'seasoned rice wine vinegar', 'champagne vinegar', 'root beer', 'ginger beer',
  'rum extract', 'rum flavoring', 'brandy extract'
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
