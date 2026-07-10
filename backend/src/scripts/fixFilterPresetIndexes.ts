import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { LastFilterPresetModel } from '../modules/filters/models/LastFilterPreset';

dotenv.config();

async function main() {
  const mongoUri = process.env.MONGODB_URI ?? process.env.MONGO_URI ?? process.env.DATABASE_URL;
  if (!mongoUri) {
    console.error('MongoDB URI not found. Set MONGODB_URI to run filter preset index migration.');
    process.exitCode = 1;
    return;
  }
  await mongoose.connect(mongoUri);
  const collection = LastFilterPresetModel.collection;
  const indexes = await collection.indexes();
  console.log('[FilterPresetIndexFix] Current indexes:');
  for (const index of indexes) {
    console.log(`- ${index.name}: ${JSON.stringify(index.key)} unique=${index.unique === true}`);
  }

  for (const index of indexes) {
    const key = index.key ?? {};
    const isOldPairKeyUnique = index.unique === true && key.mode === 1 && key.pairKey === 1 && Object.keys(key).length === 2;
    if (!isOldPairKeyUnique || !index.name) continue;
    console.log(`[FilterPresetIndexFix] Dropping old unique index ${index.name}`);
    await collection.dropIndex(index.name);
  }

  console.log('[FilterPresetIndexFix] Ensuring unique paired user index mode+userId+pairKey');
  await collection.createIndex(
    { mode: 1, userId: 1, pairKey: 1 },
    {
      name: 'mode_1_userId_1_pairKey_1',
      unique: true,
      partialFilterExpression: {
        mode: 'paired',
        userId: { $exists: true, $type: 'objectId' },
        pairKey: { $exists: true, $type: 'string' }
      }
    }
  );

  const nextIndexes = await collection.indexes();
  console.log('[FilterPresetIndexFix] Final indexes:');
  for (const index of nextIndexes) {
    console.log(`- ${index.name}: ${JSON.stringify(index.key)} unique=${index.unique === true}`);
  }
}

main()
  .catch((error) => {
    console.error('[FilterPresetIndexFix] Failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
