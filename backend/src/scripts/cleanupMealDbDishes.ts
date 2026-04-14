import { connectDatabase } from '../config/database';
import { DishModel } from '../modules/dishes/models/Dish';

function hasApplyFlag() {
  return process.argv.includes('--apply');
}

async function run() {
  await connectDatabase();

  const mealDbFilter = {
    $or: [
      { sourceType: 'mealdb' },
      { source: { $in: ['mealdb'] } }
    ]
  };

  const count = await DishModel.countDocuments(mealDbFilter);
  if (!hasApplyFlag()) {
    console.log(`[dry-run] Found ${count} dishes marked as MealDB imports.`);
    console.log('[dry-run] Re-run with --apply to delete these dishes.');
    process.exit(0);
  }

  const result = await DishModel.deleteMany(mealDbFilter);
  console.log(`[apply] Deleted ${result.deletedCount ?? 0} MealDB-imported dishes.`);
  process.exit(0);
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
