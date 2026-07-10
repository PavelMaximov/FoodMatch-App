const UNIT_WORDS = new Set([
  'cup', 'cups', 'tbsp', 'tbsps', 'tablespoon', 'tablespoons', 'tsp', 'tsps', 'teaspoon', 'teaspoons',
  'g', 'kg', 'gram', 'grams', 'oz', 'ounce', 'ounces', 'lb', 'lbs', 'pound', 'pounds', 'ml', 'l', 'liter', 'liters',
  'pinch', 'pinches', 'dash', 'dashes', 'slice', 'slices', 'clove', 'cloves', 'can', 'cans', 'package', 'packages',
  'packet', 'packets', 'bunch', 'bunches', 'sprig', 'sprigs', 'piece', 'pieces'
]);

const PREPARATION_WORDS = new Set([
  'fresh', 'dried', 'dry', 'ground', 'crushed', 'chopped', 'diced', 'minced', 'sliced', 'grated', 'shredded',
  'peeled', 'seeded', 'cooked', 'uncooked', 'drained', 'rinsed', 'optional', 'to', 'taste', 'plus', 'more', 'for',
  'serving', 'divided', 'softened', 'melted', 'large', 'small', 'medium', 'roughly', 'finely', 'thinly', 'coarsely'
]);

const MEASUREMENT_PATTERNS = [
  /^\d+(?:[./]\d+)?$/,
  /^\d+\/\d+$/,
  /^\d+(?:\.\d+)?(?:g|kg|ml|l|oz|lb|lbs)$/,
];

export function normalizeIngredientText(input: string): string {
  const basic = normalizeBasic(input);
  const tokens = basic
    .split(' ')
    .filter((token) => token.length > 0)
    .filter((token) => !MEASUREMENT_PATTERNS.some((pattern) => pattern.test(token)))
    .filter((token) => !UNIT_WORDS.has(token));

  return tokens.join(' ').replace(/\s+/g, ' ').trim();
}

export function normalizeIngredientKey(input: string): string {
  return normalizeIngredientText(input).replace(/\s+/g, '_');
}

export function tokenizeIngredient(input: string): string[] {
  const normalized = normalizeIngredientText(input);
  if (!normalized) return [];
  return normalized
    .split(' ')
    .filter((token) => token.length > 0)
    .filter((token) => !PREPARATION_WORDS.has(token));
}

export function isLikelyNoiseIngredient(input: string): boolean {
  const trimmed = (input ?? '').trim();
  if (!trimmed) return true;

  const normalized = normalizeIngredientText(trimmed);
  if (!normalized) return true;
  if (/^\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?$/.test(trimmed)) return true;
  if (/^(?:for\s+)?[$€£]?\d+(?:\.\d{2})?$/.test(normalized)) return true;
  if (/\b(?:walmart|aldi|costco|target|tesco|sainsbury|kroger|whole foods|trader joe)\b/.test(normalized)) return true;

  const tokens = normalized.split(' ');
  if (tokens.every((token) => UNIT_WORDS.has(token))) return true;
  if (tokens.length === 1 && (UNIT_WORDS.has(tokens[0]) || MEASUREMENT_PATTERNS.some((pattern) => pattern.test(tokens[0])))) return true;
  if (normalized.length < 2) return true;

  return false;
}

function normalizeBasic(input: string): string {
  return (input ?? '')
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[’']/g, '')
    .replace(/[‐‑‒–—−-]/g, ' ')
    .replace(/\([^)]*\)/g, ' ')
    .replace(/\b\d+(?:\.\d+)?\s*(?:x|×)\s*\d+(?:\.\d+)?\b/g, ' ')
    .replace(/[™®©]/g, ' ')
    .replace(/[^a-zA-Z0-9\s/.$€£]/g, ' ')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}
