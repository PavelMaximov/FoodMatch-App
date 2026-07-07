import fs from 'fs';
import path from 'path';
import { extractDishIngredientTexts, getExclusionTagsForIngredient, getMatchedExclusionReason } from '../shared/ingredients/exclusionMatcher';
import { isLikelyNoiseIngredient, normalizeIngredientText } from '../shared/ingredients/ingredientNormalizer';

type IngredientCount = { ingredient: string; count: number };
type ParseResult = { ok: true; value: unknown } | { ok: false; error: string; line: number; column: number; position: number; snippet: string; likelyFix?: string };

const EXCLUSION_KEYS = ['no_nuts', 'no_dairy', 'no_gluten', 'no_eggs', 'no_meat', 'no_pork', 'no_beef', 'no_chicken', 'no_fish', 'no_seafood', 'no_spicy', 'no_alcohol'];
const EXCLUSION_TAGS = ['nuts', 'dairy', 'gluten', 'eggs', 'meat', 'pork', 'beef', 'chicken', 'fish', 'seafood', 'spicy', 'alcohol'];

const repoRoot = path.resolve(__dirname, '../..');
const projectRoot = path.resolve(repoRoot, '..');
const args = parseArgs(process.argv.slice(2));
const expectedDishesPath = path.join(repoRoot, 'data/seed/dishes_v5.json');
const expectedIngredientsPath = path.join(repoRoot, 'data/seed/ingredients.txt');
const dishesPath = path.resolve(projectRoot, args.dishes ?? path.relative(projectRoot, expectedDishesPath));
const ingredientsPath = path.resolve(projectRoot, args.ingredients ?? path.relative(projectRoot, expectedIngredientsPath));
const missingFiles = [
  !fs.existsSync(dishesPath) ? path.relative(projectRoot, dishesPath) : null,
  !fs.existsSync(ingredientsPath) ? path.relative(projectRoot, ingredientsPath) : null
].filter((value): value is string => Boolean(value));

if (missingFiles.length > 0) {
  console.error(JSON.stringify({
    error: 'Ingredient audit seed files are missing.',
    missingFiles,
    expectedPaths: {
      dishes: path.relative(projectRoot, expectedDishesPath),
      ingredients: path.relative(projectRoot, expectedIngredientsPath)
    },
    cliOverrideExample: 'npm run audit:ingredients -- --dishes backend/data/seed/dishes_v5.json --ingredients backend/data/seed/ingredients.txt'
  }, null, 2));
  process.exit(2);
}

const dishesRaw = fs.readFileSync(dishesPath, 'utf8');
const parsed = parseJsonWithLocation(dishesRaw);
if (!parsed.ok) {
  console.error(JSON.stringify({
    error: 'dishes_v5.json is not valid JSON.',
    details: parsed,
    recommendedFix: parsed.likelyFix ?? 'Open the file at the reported line/column and fix the JSON syntax before re-running audit.'
  }, null, 2));
  process.exit(2);
}

const dishes = coerceDishArray(parsed.value);
const ingredientLines = fs.readFileSync(ingredientsPath, 'utf8').split(/\r?\n/);
const dishStats = collectDishStats(dishes);
const txtStats = collectIngredientsTxtStats(ingredientLines, dishStats.normalizedCounts);
const report = buildIngredientReport(dishStats, txtStats);
const exclusionReport = buildExclusionAuditReport(dishes);

const generatedDir = path.join(repoRoot, 'generated');
fs.mkdirSync(generatedDir, { recursive: true });
const ingredientReportPath = path.join(generatedDir, 'ingredient-audit-report.json');
const exclusionReportPath = path.join(generatedDir, 'exclusion-audit-report.json');
fs.writeFileSync(ingredientReportPath, `${JSON.stringify(report, null, 2)}\n`);
fs.writeFileSync(exclusionReportPath, `${JSON.stringify(exclusionReport, null, 2)}\n`);

console.log(JSON.stringify({
  summary: report.summary,
  dishesValidation: report.dishesValidation,
  outputFiles: {
    ingredientAudit: path.relative(projectRoot, ingredientReportPath),
    exclusionAudit: path.relative(projectRoot, exclusionReportPath)
  }
}, null, 2));

function collectDishStats(dishes: unknown[]) {
  const normalizedCounts = new Map<string, number>();
  const rawTextCounts = new Map<string, number>();
  const ingredientNameCounts = new Map<string, number>();
  const rawDiffersFromName: Array<{ dishId: string; dishName: string; rawText: string; ingredientName: string }> = [];
  const missingSectionsOrComponents: Array<{ dishId: string; dishName: string; reason: string }> = [];
  const missingIngredientNames: Array<{ dishId: string; dishName: string; rawText: string }> = [];
  let approvedDishes = 0;
  let ingredientComponentCount = 0;

  dishes.forEach((dish: any, dishIndex) => {
    if (dish?.status === 'approved' || dish?.status === undefined) approvedDishes += 1;
    const dishId = String(dish?.id ?? dish?._id ?? dish?.sourceId ?? dishIndex);
    const dishName = String(dish?.name ?? dish?.title ?? 'Unknown dish');
    if (!Array.isArray(dish?.sections) || dish.sections.length === 0) {
      missingSectionsOrComponents.push({ dishId, dishName, reason: 'missing_sections' });
    }
    let componentsSeen = 0;
    if (Array.isArray(dish?.sections)) {
      dish.sections.forEach((section: any) => {
        if (!Array.isArray(section?.components) || section.components.length === 0) return;
        componentsSeen += section.components.length;
        section.components.forEach((component: any) => {
          ingredientComponentCount += 1;
          const rawText = String(component?.raw_text ?? '').trim();
          const ingredientName = String(component?.ingredient?.name ?? '').trim();
          if (rawText) increment(rawTextCounts, normalizeIngredientText(rawText));
          if (ingredientName) increment(ingredientNameCounts, normalizeIngredientText(ingredientName));
          if (!ingredientName) missingIngredientNames.push({ dishId, dishName, rawText });
          if (rawText && ingredientName && normalizeIngredientText(rawText) !== normalizeIngredientText(ingredientName)) {
            rawDiffersFromName.push({ dishId, dishName, rawText, ingredientName });
          }
        });
      });
    }
    if (componentsSeen === 0) missingSectionsOrComponents.push({ dishId, dishName, reason: 'missing_components' });
    for (const candidate of extractDishIngredientTexts(dish)) {
      const normalized = normalizeIngredientText(candidate.text);
      if (normalized && !isLikelyNoiseIngredient(candidate.text)) increment(normalizedCounts, normalized);
    }
  });

  return { approvedDishes, ingredientComponentCount, normalizedCounts, rawTextCounts, ingredientNameCounts, rawDiffersFromName, missingSectionsOrComponents, missingIngredientNames };
}

function collectIngredientsTxtStats(lines: string[], dishCounts: Map<string, number>) {
  const normalizedCounts = new Map<string, number>();
  const noiseExamples: string[] = [];
  const encodingArtifactExamples: string[] = [];
  const priceDateStoreExamples: string[] = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    const normalized = normalizeIngredientText(trimmed);
    if (/ã|â|�/.test(trimmed)) encodingArtifactExamples.push(trimmed);
    if (/\b(?:for\s+)?\d+\.\d{2}\b|^\d{1,2}[/-]\d{1,2}|\b(?:walmart|aldi|costco|target|tesco|kroger)\b/i.test(trimmed)) priceDateStoreExamples.push(trimmed);
    if (isLikelyNoiseIngredient(trimmed)) {
      noiseExamples.push(trimmed);
      continue;
    }
    if (normalized) increment(normalizedCounts, normalized);
  }
  const duplicateExamples = [...normalizedCounts.entries()].filter(([, count]) => count > 1).slice(0, 100).map(([ingredient, count]) => ({ ingredient, count }));
  const usefulIngredientsMissingFromDishData = [...normalizedCounts.keys()].filter((ingredient) => !dishCounts.has(ingredient)).sort().slice(0, 500);
  return { normalizedCounts, noiseExamples, encodingArtifactExamples, priceDateStoreExamples, duplicateExamples, usefulIngredientsMissingFromDishData, totalLines: lines.length };
}

function buildIngredientReport(dishStats: ReturnType<typeof collectDishStats>, txtStats: ReturnType<typeof collectIngredientsTxtStats>) {
  const dishIngredients = new Set(dishStats.normalizedCounts.keys());
  const txtIngredients = new Set(txtStats.normalizedCounts.keys());
  const exclusionRelevantIngredients: Record<string, string[]> = Object.fromEntries(EXCLUSION_TAGS.map((tag) => [tag, []]));
  for (const ingredient of new Set([...dishIngredients, ...txtIngredients])) {
    for (const tag of getExclusionTagsForIngredient(ingredient)) exclusionRelevantIngredients[tag]?.push(ingredient);
  }
  for (const tag of Object.keys(exclusionRelevantIngredients)) exclusionRelevantIngredients[tag].sort();

  return {
    inputFiles: { dishes: path.relative(projectRoot, dishesPath), ingredients: path.relative(projectRoot, ingredientsPath) },
    dishesValidation: { validJson: true },
    summary: {
      dishCount: dishes.length,
      approvedDishes: dishStats.approvedDishes,
      ingredientComponentCount: dishStats.ingredientComponentCount,
      uniqueRawText: dishStats.rawTextCounts.size,
      uniqueIngredientNames: dishStats.ingredientNameCounts.size,
      uniqueDishIngredients: dishStats.normalizedCounts.size,
      ingredientsTxtLines: txtStats.totalLines,
      uniqueIngredientsTxt: txtStats.normalizedCounts.size,
      noiseCount: txtStats.noiseExamples.length
    },
    topDishIngredients: topCounts(dishStats.normalizedCounts, 100),
    dishIngredientsMissingFromIngredientsTxt: [...dishIngredients].filter((ingredient) => !txtIngredients.has(ingredient)).sort().slice(0, 500),
    ingredientsTxtOnly: txtStats.usefulIngredientsMissingFromDishData,
    noiseExamples: txtStats.noiseExamples.slice(0, 100),
    duplicateExamples: txtStats.duplicateExamples,
    encodingArtifactExamples: txtStats.encodingArtifactExamples.slice(0, 100),
    priceDateStoreNameJunkExamples: txtStats.priceDateStoreExamples.slice(0, 100),
    dishesWithMissingSectionsOrComponents: dishStats.missingSectionsOrComponents.slice(0, 250),
    componentsWithMissingIngredientName: dishStats.missingIngredientNames.slice(0, 250),
    rawTextDiffersFromIngredientName: dishStats.rawDiffersFromName.slice(0, 250),
    exclusionRelevantIngredients
  };
}

function buildExclusionAuditReport(dishes: unknown[]) {
  const report: Record<string, any> = {};
  for (const exclusion of EXCLUSION_KEYS) {
    const excluded = [];
    for (const dish of dishes as any[]) {
      const reason = getMatchedExclusionReason(dish, [exclusion]);
      if (!reason.matched) continue;
      excluded.push({
        dishId: String(dish?.id ?? dish?._id ?? dish?.sourceId ?? ''),
        dishName: String(dish?.name ?? dish?.title ?? ''),
        reasons: reason.reasons.map((entry) => ({
          matchedIngredient: entry.ingredient,
          normalizedIngredient: entry.normalized,
          matchedTags: entry.matchedExclusions,
          ingredientField: entry.source,
          matchSource: entry.matchSource
        }))
      });
    }
    report[exclusion] = { excludedDishCount: excluded.length, excludedDishes: excluded };
  }
  return report;
}

function parseArgs(argv: string[]) {
  const parsed: { dishes?: string; ingredients?: string } = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--dishes') parsed.dishes = argv[i + 1];
    if (argv[i] === '--ingredients') parsed.ingredients = argv[i + 1];
  }
  return parsed;
}

function increment(counts: Map<string, number>, key: string) {
  if (!key) return;
  counts.set(key, (counts.get(key) ?? 0) + 1);
}

function topCounts(counts: Map<string, number>, limit: number): IngredientCount[] {
  return [...counts.entries()].map(([ingredient, count]) => ({ ingredient, count })).sort((a, b) => b.count - a.count || a.ingredient.localeCompare(b.ingredient)).slice(0, limit);
}

function parseJsonWithLocation(raw: string): ParseResult {
  try {
    return { ok: true, value: JSON.parse(raw) };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const positionMatch = message.match(/position\s+(\d+)/i);
    const position = positionMatch ? Number(positionMatch[1]) : 0;
    const before = raw.slice(0, position);
    const lines = before.split(/\r?\n/);
    const snippet = raw.slice(Math.max(0, position - 120), Math.min(raw.length, position + 120));
    return { ok: false, error: message, line: lines.length, column: lines[lines.length - 1].length + 1, position, snippet, likelyFix: inferLikelyFix(snippet) };
  }
}

function inferLikelyFix(snippet: string) {
  if (/,[\s\r\n]*[}\]]/.test(snippet)) return 'Remove the trailing comma before the closing object/array.';
  if (/'/.test(snippet)) return 'JSON requires double quotes around strings and property names.';
  return undefined;
}

function coerceDishArray(value: unknown): unknown[] {
  if (Array.isArray(value)) return value;
  if (Array.isArray((value as any)?.dishes)) return (value as any).dishes;
  if (Array.isArray((value as any)?.recipes)) return (value as any).recipes;
  return [];
}
