import fs from 'fs';
import path from 'path';
import { extractDishIngredientTexts, getExclusionTagsForIngredient } from '../shared/ingredients/exclusionMatcher';
import { isLikelyNoiseIngredient, normalizeIngredientText } from '../shared/ingredients/ingredientNormalizer';

type IngredientCount = { ingredient: string; count: number };

const repoRoot = path.resolve(__dirname, '../..');
const projectRoot = path.resolve(repoRoot, '..');
const dishesPath = findInputFile('dishes_v5.json');
const ingredientsPath = findInputFile('ingredients.txt');

const dishesRaw = dishesPath ? fs.readFileSync(dishesPath, 'utf8') : '';
const parsed = dishesPath ? parseJsonWithLocation(dishesRaw) : { ok: false as const, error: 'dishes_v5.json not found', line: 0, column: 0, position: 0 };
const dishes = parsed.ok ? coerceDishArray(parsed.value) : extractDishLikeObjectsFromText(dishesRaw);
const ingredientLines = ingredientsPath ? fs.readFileSync(ingredientsPath, 'utf8').split(/\r?\n/) : [];

const dishIngredientCounts = new Map<string, number>();
let componentCount = 0;
const suspiciousDishIngredients = new Set<string>();
for (const dish of dishes) {
  const extracted = extractDishIngredientTexts(dish);
  componentCount += extracted.length;
  for (const candidate of extracted) addIngredient(candidate.text, dishIngredientCounts, suspiciousDishIngredients);
}

const txtIngredientCounts = new Map<string, number>();
const suspiciousTxtIngredients = new Set<string>();
for (const line of ingredientLines) addIngredient(line, txtIngredientCounts, suspiciousTxtIngredients);

const missingFromIngredientsTxt = [...dishIngredientCounts.keys()]
  .filter((ingredient) => !txtIngredientCounts.has(ingredient))
  .sort()
  .slice(0, 250);

const exclusionRelevant = [...new Set([...dishIngredientCounts.keys(), ...txtIngredientCounts.keys()])]
  .map((ingredient) => ({ ingredient, tags: getExclusionTagsForIngredient(ingredient) }))
  .filter((entry) => entry.tags.length > 0)
  .sort((a, b) => a.ingredient.localeCompare(b.ingredient));

const report = {
  inputFiles: {
    dishes_v5: dishesPath ? path.relative(projectRoot, dishesPath) : null,
    ingredients_txt: ingredientsPath ? path.relative(projectRoot, ingredientsPath) : null
  },
  dishesValidation: parsed.ok ? { validJson: true } : { validJson: false, error: parsed.error, line: parsed.line, column: parsed.column, position: parsed.position },
  totalDishes: dishes.length,
  totalIngredientComponents: componentCount,
  uniqueDishIngredientsCount: dishIngredientCounts.size,
  uniqueIngredientsTxtCount: txtIngredientCounts.size,
  top100DishIngredients: topCounts(dishIngredientCounts, 100),
  ingredientsMissingFromIngredientsTxt: missingFromIngredientsTxt,
  suspiciousNoisyIngredients: {
    dishes: [...suspiciousDishIngredients].slice(0, 100),
    ingredientsTxt: [...suspiciousTxtIngredients].slice(0, 100)
  },
  exclusionRelevantIngredients: exclusionRelevant.slice(0, 500)
};

const generatedDir = path.join(repoRoot, 'generated');
fs.mkdirSync(generatedDir, { recursive: true });
const outputPath = path.join(generatedDir, 'ingredient-audit-report.json');
fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`);

console.log(JSON.stringify({ ...report, outputPath: path.relative(projectRoot, outputPath) }, null, 2));
if (!parsed.ok) process.exitCode = 2;

function addIngredient(value: string, counts: Map<string, number>, suspicious: Set<string>) {
  const normalized = normalizeIngredientText(value);
  if (!normalized) return;
  if (isLikelyNoiseIngredient(value)) {
    suspicious.add(value.trim());
    return;
  }
  counts.set(normalized, (counts.get(normalized) ?? 0) + 1);
}

function topCounts(counts: Map<string, number>, limit: number): IngredientCount[] {
  return [...counts.entries()]
    .map(([ingredient, count]) => ({ ingredient, count }))
    .sort((a, b) => b.count - a.count || a.ingredient.localeCompare(b.ingredient))
    .slice(0, limit);
}

function findInputFile(fileName: string) {
  const candidates = [
    path.join(projectRoot, fileName),
    path.join(repoRoot, fileName),
    path.join(process.cwd(), fileName)
  ];
  return candidates.find((candidate) => fs.existsSync(candidate)) ?? null;
}

function parseJsonWithLocation(raw: string): { ok: true; value: unknown } | { ok: false; error: string; line: number; column: number; position: number } {
  try {
    return { ok: true, value: JSON.parse(raw) };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const positionMatch = message.match(/position\s+(\d+)/i);
    const position = positionMatch ? Number(positionMatch[1]) : 0;
    const before = raw.slice(0, position);
    const lines = before.split(/\r?\n/);
    return { ok: false, error: message, line: lines.length, column: lines[lines.length - 1].length + 1, position };
  }
}

function coerceDishArray(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (Array.isArray((value as any)?.dishes)) return (value as any).dishes;
  if (Array.isArray((value as any)?.recipes)) return (value as any).recipes;
  return [];
}

function extractDishLikeObjectsFromText(raw: string): unknown[] {
  if (!raw) return [];
  const ingredientMatches = [...raw.matchAll(/"(?:raw_text|name|display_singular|display_plural)"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"/g)]
    .map((match) => match[1].replace(/\\"/g, '"'));
  if (ingredientMatches.length === 0) return [];
  return [{ ingredients: ingredientMatches }];
}
