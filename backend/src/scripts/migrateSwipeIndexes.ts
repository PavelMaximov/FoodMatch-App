import dotenv from 'dotenv';
import mongoose from 'mongoose';

dotenv.config();

type IndexSpec = {
  name?: string;
  key: Record<string, 1 | -1>;
  unique?: boolean;
};

const obsoleteSwipeIndexKey = { userId: 1, dishId: 1 } as const;
const correctSwipeIndexKey = { userId: 1, coupleId: 1, dishId: 1 } as const;

function sameIndexKey(left: Record<string, unknown>, right: Record<string, unknown>): boolean {
  const leftEntries = Object.entries(left);
  const rightEntries = Object.entries(right);
  return leftEntries.length === rightEntries.length && leftEntries.every(([key, value]) => right[key] === value);
}

async function main() {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error('MONGODB_URI is required to migrate swipe indexes.');
  }

  await mongoose.connect(mongoUri);
  const swipes = mongoose.connection.collection('swipes');

  const beforeIndexes = (await swipes.indexes()) as IndexSpec[];
  console.log('[SwipeIndexMigration] Current swipes indexes before migration:');
  console.dir(beforeIndexes, { depth: null });

  const duplicateGroups = await swipes
    .aggregate([
      {
        $group: {
          _id: {
            userId: '$userId',
            coupleId: '$coupleId',
            dishId: '$dishId'
          },
          count: { $sum: 1 },
          ids: { $push: '$_id' }
        }
      },
      { $match: { count: { $gt: 1 } } }
    ])
    .toArray();

  if (duplicateGroups.length > 0) {
    console.error('[SwipeIndexMigration] Duplicate swipes exist for the target unique index. Resolve these before creating the unique index:');
    console.dir(duplicateGroups, { depth: null });
    process.exitCode = 1;
    return;
  }

  for (const index of beforeIndexes) {
    if (index.name && sameIndexKey(index.key, obsoleteSwipeIndexKey)) {
      console.log(`[SwipeIndexMigration] Dropping obsolete index ${index.name}`);
      await swipes.dropIndex(index.name);
    }
  }

  console.log('[SwipeIndexMigration] Ensuring correct unique index { userId: 1, coupleId: 1, dishId: 1 }');
  await swipes.createIndex(correctSwipeIndexKey, {
    unique: true,
    name: 'userId_1_coupleId_1_dishId_1'
  });

  const afterIndexes = await swipes.indexes();
  console.log('[SwipeIndexMigration] Swipes indexes after migration:');
  console.dir(afterIndexes, { depth: null });
}

main()
  .catch((error) => {
    console.error('[SwipeIndexMigration] Failed', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
