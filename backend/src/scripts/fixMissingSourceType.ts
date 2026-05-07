import { connect, disconnect } from 'mongoose';
import { DishModel } from '../modules/dishes/models/Dish';

async function fixMissingSourceType() {
  try {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/foodmatch-dev';
    await connect(mongoUri);
    console.log('✅ Connected to MongoDB');

    // Find all dishes with undefined or missing sourceType
    const dishesWithoutSourceType = await DishModel.find({
      $or: [
        { sourceType: { $exists: false } },
        { sourceType: undefined },
        { sourceType: null }
      ]
    });

    console.log(`\n📊 Found ${dishesWithoutSourceType.length} dishes with missing/undefined sourceType\n`);

    if (dishesWithoutSourceType.length > 0) {
      console.log('Dishes:');
      dishesWithoutSourceType.forEach((dish) => {
        console.log(`  - _id: ${dish._id}, name: ${dish.name}, sourceId: ${dish.sourceId || 'NOT SET'}`);
      });

      // Set sourceType to 'mealdb' if sourceId exists, otherwise 'custom'
      const result = await DishModel.updateMany(
        {
          $or: [
            { sourceType: { $exists: false } },
            { sourceType: undefined },
            { sourceType: null }
          ]
        },
        [
          {
            $set: {
              sourceType: {
                $cond: [
                  { $ne: ['$sourceId', null] },
                  'mealdb',
                  'custom'
                ]
              }
            }
          }
        ]
      );

      console.log(`\n✅ Updated ${result.modifiedCount} dishes`);
    } else {
      console.log('✅ No dishes with missing sourceType found');
    }

    await disconnect();
    console.log('\n✅ Disconnected from MongoDB');
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

fixMissingSourceType();
