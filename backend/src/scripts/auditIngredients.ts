import dotenv from 'dotenv';
import fs from 'fs';
import mongoose from 'mongoose';
import path from 'path';
import { DishModel } from '../modules/dishes/models/Dish';
import { extractDishIngredientTexts, getExclusionTagsForIngredient, getMatchedExclusionReason } from '../shared/ingredients/exclusionMatcher';
import { isLikelyNoiseIngredient, normalizeIngredientKey, normalizeIngredientText } from '../shared/ingredients/ingredientNormalizer';

dotenv.config();

type IngredientCount = { ingredient: string; count: number };
type SourceMode = 'mongo' | 'files';
type ParseResult = { ok: true; value: unknown } | { ok: false; error: string; line: number; column: number; position: number; snippet: string; likelyFix?: string };

type IngredientCatalogRecord = { name: string; aliases: string[]; raw: unknown };

const EXCLUSION_KEYS = ['no_meat', 'no_dairy', 'no_gluten', 'no_nuts', 'no_seafood', 'no_eggs', 'no_pork', 'no_beef', 'no_chicken', 'no_fish', 'no_spicy', 'no_alcohol'];
const EXCLUSION_TAGS = ['nuts', 'dairy', 'gluten', 'eggs', 'meat', 'pork', 'beef', 'chicken', 'fish', 'seafood', 'spicy', 'alcohol'];

const repoRoot = path.resolve(__dirname, '../..');
const projectRoot = path.resolve(repoRoot, '..');
const args = parseArgs(process.argv.slice(2));
const source = args.source ?? 'mongo';

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});

async function main() {
  const loaded = source === 'mongo' ? await loadMongoSource() : loadFileSource();
  const dishStats = collectDishStats(loaded.dishes);
  const catalogStats = collectIngredientCatalogStats(loaded.ingredients, dishStats.normalizedCounts);
  const report = buildIngredientReport(loaded, dishStats, catalogStats);
  const exclusionReport = buildExclusionAuditReport(loaded.dishes);

  const generatedDir = path.join(repoRoot, 'generated');
  fs.mkdirSync(generatedDir, { recursive: true });
  const ingredientReportPath = path.join(generatedDir, 'ingredient-audit-report.json');
  const exclusionReportPath = path.join(generatedDir, 'exclusion-audit-report.json');
  fs.writeFileSync(ingredientReportPath, `${JSON.stringify(report, null, 2)}\n`);
  fs.writeFileSync(exclusionReportPath, `${JSON.stringify(exclusionReport, null, 2)}\n`);

  console.log(JSON.stringify({
    summary: report.summary,
    source: loaded.source,
    dbName: loaded.dbName,
    warnings: loaded.warnings,
    outputFiles: {
      ingredientAudit: path.relative(projectRoot, ingredientReportPath),
      exclusionAudit: path.relative(projectRoot, exclusionReportPath)
    }
  }, null, 2));

  if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
}

async function loadMongoSource() {
  const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URI || process.env.DATABASE_URL;
  if (!mongoUri) {
    throw new Error('MongoDB URI not found. Set MONGODB_URI or use --source files.');
  }
  try {
    await mongoose.connect(mongoUri, args.dbName ? { dbName: args.dbName } : undefined);
  } catch (error) {
    throw new Error(`Failed to connect to MongoDB. Set MONGODB_URI or use --source files. ${error instanceof Error ? error.message : String(error)}`);
  }

  const db = mongoose.connection.db;
  if (!db) throw new Error('MongoDB connection did not expose a database handle.');

  const collectionNames = (await db.listCollections().toArray()).map((collection) => collection.name).sort();
  const dishesCollection = args.dishesCollection ?? DishModel.collection.name;
  if (!collectionNames.includes(dishesCollection)) {
    throw new Error(`Dishes collection "${dishesCollection}" not found. Available collections: ${collectionNames.join(', ') || '(none)'}`);
  }

  const dishes = await DishModel.find({
    status: { $in: ['approved', 'active'] },
    $or: [{ visibility: { $exists: false } }, { visibility: { $in: ['public', 'session', 'private'] } }]
  })
    .select('_id id sourceId name title status visibility cuisine type diet tags mood ingredients structuredIngredients sections')
    .lean();

  const ingredientsCollection = args.ingredientsCollection ?? 'ingredients';
  const warnings: string[] = [];
  let ingredients: IngredientCatalogRecord[] = [];
  if (collectionNames.includes(ingredientsCollection)) {
    const docs = await db.collection(ingredientsCollection).find({}).toArray();
    ingredients = docs.map(readIngredientCatalogRecord).filter((entry): entry is IngredientCatalogRecord => Boolean(entry));
  } else if (args.requireIngredients) {
    throw new Error(`Ingredient collection "${ingredientsCollection}" not found. Available collections: ${collectionNames.join(', ') || '(none)'}`);
  } else {
    warnings.push('Ingredient collection not found; auditing dish ingredients only.');
  }

  return {
    source: 'mongo' as const,
    dbName: mongoose.connection.name || args.dbName || null,
    inputFiles: null,
    collectionNames: { dishes: dishesCollection, ingredients: collectionNames.includes(ingredientsCollection) ? ingredientsCollection : null },
    warnings,
    dishes,
    ingredients
  };
}

function loadFileSource() {
  const expectedDishesPath = path.join(repoRoot, 'data/seed/dishes_v5.json');
  const expectedIngredientsPath = path.join(repoRoot, 'data/seed/ingredients.txt');
  const dishesPath = path.resolve(projectRoot, args.dishes ?? path.relative(projectRoot, expectedDishesPath));
  const ingredientsPath = path.resolve(projectRoot, args.ingredients ?? path.relative(projectRoot, expectedIngredientsPath));
  const missingFiles = [
    !fs.existsSync(dishesPath) ? path.relative(projectRoot, dishesPath) : null,
    !fs.existsSync(ingredientsPath) ? path.relative(projectRoot, ingredientsPath) : null
  ].filter((value): value is string => Boolean(value));

  if (missingFiles.length > 0) {
    throw new Error(JSON.stringify({
      error: 'Ingredient audit seed files are missing.',
      missingFiles,
      expectedPaths: {
        dishes: path.relative(projectRoot, expectedDishesPath),
        ingredients: path.relative(projectRoot, expectedIngredientsPath)
      },
      cliOverrideExample: 'npm run audit:ingredients:files -- --dishes backend/data/seed/dishes_v5.json --ingredients backend/data/seed/ingredients.txt'
    }, null, 2));
  }

  const parsed = parseJsonWithLocation(fs.readFileSync(dishesPath, 'utf8'));
  if (!parsed.ok) {
    throw new Error(JSON.stringify({ error: 'dishes_v5.json is not valid JSON.', details: parsed, recommendedFix: parsed.likelyFix ?? 'Open the file at the reported line/column and fix the JSON syntax before re-running audit.' }, null, 2));
  }

  const dishes = coerceDishArray(parsed.value);
  const ingredients = fs.readFileSync(ingredientsPath, 'utf8')
    .split(/\r?\n/)
    .filter((line) => line.trim().length > 0)
    .map((line) => ({ name: line.trim(), aliases: [], raw: line }));

  return {
    source: 'files' as const,
    dbName: null,
    inputFiles: { dishes: path.relative(projectRoot, dishesPath), ingredients: path.relative(projectRoot, ingredientsPath) },
    collectionNames: null,
    warnings: [],
    dishes,
    ingredients
  };
}

function collectDishStats(dishes: unknown[]) {
  const normalizedCounts = new Map<string, number>();
  const rawTextCounts = new Map<string, number>();
  const ingredientNameCounts = new Map<string, number>();
  const rawDiffersFromName: Array<{ dishId: string; dishName: string; rawText: string; ingredientName: string }> = [];
  const missingSectionsOrComponents: Array<{ dishId: string; dishName: string; reason: string }> = [];
  const missingIngredientNames: Array<{ dishId: string; dishName: string; rawText: string }> = [];
  let approvedDishes = 0;
  let visibleDishes = 0;
  let dishesWithSectionsComponents = 0;
  let dishesWithFlattenedIngredientsOnly = 0;
  let dishesWithNoIngredients = 0;
  let ingredientComponentCount = 0;

  dishes.forEach((dish: any, dishIndex) => {
    if (dish?.status === 'approved' || dish?.status === undefined) approvedDishes += 1;
    if (!dish?.visibility || ['public', 'session', 'private'].includes(dish.visibility)) visibleDishes += 1;
    const dishId = String(dish?.id ?? dish?._id ?? dish?.sourceId ?? dishIndex);
    const dishName = String(dish?.name ?? dish?.title ?? 'Unknown dish');
    const hasFlattenedIngredients = Array.isArray(dish?.ingredients) && dish.ingredients.length > 0;
    let componentsSeen = 0;

    if (!Array.isArray(dish?.sections) || dish.sections.length === 0) {
      missingSectionsOrComponents.push({ dishId, dishName, reason: 'missing_sections' });
    }
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
          if (rawText && ingredientName && normalizeIngredientText(rawText) !== normalizeIngredientText(ingredientName)) rawDiffersFromName.push({ dishId, dishName, rawText, ingredientName });
        });
      });
    }

    if (componentsSeen > 0) dishesWithSectionsComponents += 1;
    if (componentsSeen === 0) missingSectionsOrComponents.push({ dishId, dishName, reason: 'missing_components' });
    if (componentsSeen === 0 && hasFlattenedIngredients) dishesWithFlattenedIngredientsOnly += 1;
    const extracted = extractDishIngredientTexts(dish);
    if (extracted.length === 0) dishesWithNoIngredients += 1;
    for (const candidate of extracted) {
      const normalized = normalizeIngredientText(candidate.text);
      if (normalized && !isLikelyNoiseIngredient(candidate.text)) increment(normalizedCounts, normalized);
    }
  });

  return { approvedDishes, visibleDishes, dishesWithSectionsComponents, dishesWithFlattenedIngredientsOnly, dishesWithNoIngredients, ingredientComponentCount, normalizedCounts, rawTextCounts, ingredientNameCounts, rawDiffersFromName, missingSectionsOrComponents, missingIngredientNames };
}

function collectIngredientCatalogStats(records: IngredientCatalogRecord[], dishCounts: Map<string, number>) {
  const normalizedCounts = new Map<string, number>();
  const noiseExamples: string[] = [];
  const encodingArtifactExamples: string[] = [];
  const priceDateStoreExamples: string[] = [];
  for (const record of records) {
    for (const value of [record.name, ...record.aliases]) {
      const trimmed = value.trim();
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
  }
  const duplicateExamples = [...normalizedCounts.entries()].filter(([, count]) => count > 1).slice(0, 100).map(([ingredient, count]) => ({ ingredient, count }));
  const usefulIngredientsMissingFromDishData = [...normalizedCounts.keys()].filter((ingredient) => !dishCounts.has(ingredient)).sort().slice(0, 500);
  return { normalizedCounts, noiseExamples, encodingArtifactExamples, priceDateStoreExamples, duplicateExamples, usefulIngredientsMissingFromDishData, totalRecords: records.length };
}

function buildIngredientReport(loaded: Awaited<ReturnType<typeof loadMongoSource>> | ReturnType<typeof loadFileSource>, dishStats: ReturnType<typeof collectDishStats>, catalogStats: ReturnType<typeof collectIngredientCatalogStats>) {
  const dishIngredients = new Set(dishStats.normalizedCounts.keys());
  const catalogIngredients = new Set(catalogStats.normalizedCounts.keys());
  const exclusionRelevantIngredients: Record<string, string[]> = Object.fromEntries(EXCLUSION_TAGS.map((tag) => [tag, []]));
  for (const ingredient of new Set([...dishIngredients, ...catalogIngredients])) {
    for (const tag of getExclusionTagsForIngredient(ingredient)) exclusionRelevantIngredients[tag]?.push(ingredient);
  }
  for (const tag of Object.keys(exclusionRelevantIngredients)) exclusionRelevantIngredients[tag].sort();

  return {
    source: loaded.source,
    dbName: loaded.dbName,
    inputFiles: loaded.inputFiles,
    collections: loaded.collectionNames,
    warnings: loaded.warnings,
    summary: {
      dishCount: loaded.dishes.length,
      approvedDishCount: dishStats.approvedDishes,
      visibleDishCount: dishStats.visibleDishes,
      dishesWithSectionsComponents: dishStats.dishesWithSectionsComponents,
      dishesWithFlattenedIngredientsOnly: dishStats.dishesWithFlattenedIngredientsOnly,
      dishesWithNoIngredients: dishStats.dishesWithNoIngredients,
      ingredientComponentCount: dishStats.ingredientComponentCount,
      uniqueRawText: dishStats.rawTextCounts.size,
      uniqueIngredientNames: dishStats.ingredientNameCounts.size,
      uniqueDishIngredients: dishStats.normalizedCounts.size,
      ingredientsCollectionCount: catalogStats.totalRecords,
      uniqueIngredientsCollectionItems: catalogStats.normalizedCounts.size,
      noiseCount: catalogStats.noiseExamples.length
    },
    topDishIngredients: topCounts(dishStats.normalizedCounts, 100),
    dishIngredientsMissingFromIngredientCollection: [...dishIngredients].filter((ingredient) => !catalogIngredients.has(ingredient)).sort().slice(0, 500),
    ingredientCollectionOnly: catalogStats.usefulIngredientsMissingFromDishData,
    noiseExamples: catalogStats.noiseExamples.slice(0, 100),
    duplicateExamples: catalogStats.duplicateExamples,
    encodingArtifactExamples: catalogStats.encodingArtifactExamples.slice(0, 100),
    priceDateStoreNameJunkExamples: catalogStats.priceDateStoreExamples.slice(0, 100),
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
        reasons: reason.reasons.map((entry) => ({ matchedIngredient: entry.ingredient, normalizedIngredient: entry.normalized, matchedTags: entry.matchedExclusions, ingredientField: entry.source, matchSource: entry.matchSource }))
      });
    }
    report[exclusion] = { excludedDishCount: excluded.length, excludedDishes: excluded };
  }
  return report;
}

function readIngredientCatalogRecord(doc: any): IngredientCatalogRecord | null {
  const name = firstString(doc?.canonicalName, doc?.name, doc?.displayName, doc?.rawName, doc?.ingredient?.name);
  if (!name) return null;
  const aliases = Array.isArray(doc?.aliases) ? doc.aliases.filter((alias: unknown): alias is string => typeof alias === 'string') : [];
  return { name, aliases, raw: doc };
}

function firstString(...values: unknown[]) {
  for (const value of values) if (typeof value === 'string' && value.trim()) return value.trim();
  return '';
}

function parseArgs(argv: string[]) {
  const parsed: { source?: SourceMode; dishes?: string; ingredients?: string; dishesCollection?: string; ingredientsCollection?: string; dbName?: string; requireIngredients?: boolean } = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--source' && (argv[i + 1] === 'mongo' || argv[i + 1] === 'files')) parsed.source = argv[i + 1] as SourceMode;
    if (argv[i] === '--dishes') parsed.dishes = argv[i + 1];
    if (argv[i] === '--ingredients') parsed.ingredients = argv[i + 1];
    if (argv[i] === '--dishes-collection') parsed.dishesCollection = argv[i + 1];
    if (argv[i] === '--ingredients-collection') parsed.ingredientsCollection = argv[i + 1];
    if (argv[i] === '--db-name') parsed.dbName = argv[i + 1];
    if (argv[i] === '--require-ingredients') parsed.requireIngredients = true;
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
