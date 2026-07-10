import dotenv from 'dotenv';
import fs from 'fs';
import mongoose from 'mongoose';
import path from 'path';
import { isLikelyNoiseIngredient, normalizeIngredientKey, normalizeIngredientText } from '../shared/ingredients/ingredientNormalizer';

dotenv.config();

const args = parseArgs(process.argv.slice(2));
const repoRoot = path.resolve(__dirname, '../..');
const projectRoot = path.resolve(repoRoot, '..');

main().catch(async (error) => {
  console.error(error instanceof Error ? error.message : error);
  if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
  process.exit(1);
});

async function main() {
  const filePath = path.resolve(projectRoot, args.file ?? 'backend/data/seed/ingredients.txt');
  if (!fs.existsSync(filePath)) throw new Error(`Ingredients file not found: ${path.relative(projectRoot, filePath)}`);
  const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URI || process.env.DATABASE_URL;
  if (!mongoUri) throw new Error('MongoDB URI not found. Set MONGODB_URI before importing ingredients.');
  await mongoose.connect(mongoUri, args.dbName ? { dbName: args.dbName } : undefined);
  const db = mongoose.connection.db;
  if (!db) throw new Error('MongoDB connection did not expose a database handle.');
  const collection = db.collection(args.collection ?? 'ingredients');

  let read = 0;
  let skippedNoise = 0;
  let upsertedOrUpdated = 0;
  for (const line of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const rawName = line.trim();
    if (!rawName) continue;
    read += 1;
    if (isLikelyNoiseIngredient(rawName)) {
      skippedNoise += 1;
      continue;
    }
    const canonicalName = normalizeIngredientText(rawName);
    const key = normalizeIngredientKey(rawName);
    if (!canonicalName || !key) continue;
    const existing = await collection.findOne({ key });
    const update: Record<string, unknown> = {
      $setOnInsert: { key, canonicalName, displayName: toDisplayName(canonicalName), exclusionTags: [], dietTags: [], source: ['ingredients_txt'], createdAt: new Date() },
      $addToSet: { aliases: rawName },
      $set: { updatedAt: new Date() }
    };
    if (args.overwriteTags && existing) update.$set = { ...(update.$set as object), exclusionTags: [] };
    await collection.updateOne({ key }, update, { upsert: true });
    upsertedOrUpdated += 1;
  }

  console.log(JSON.stringify({ collection: collection.collectionName, read, skippedNoise, upsertedOrUpdated }, null, 2));
  await mongoose.disconnect();
}

function parseArgs(argv: string[]) {
  const parsed: { file?: string; collection?: string; dbName?: string; overwriteTags?: boolean } = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--file') parsed.file = argv[i + 1];
    if (argv[i] === '--collection') parsed.collection = argv[i + 1];
    if (argv[i] === '--db-name') parsed.dbName = argv[i + 1];
    if (argv[i] === '--overwrite-tags') parsed.overwriteTags = true;
  }
  return parsed;
}

function toDisplayName(value: string) {
  return value.replace(/\b\w/g, (letter) => letter.toUpperCase());
}
