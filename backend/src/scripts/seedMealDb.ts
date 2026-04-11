import { connectDatabase } from '../config/database';
import { DishService } from '../modules/dishes/services/dishService';

async function run() {
  await connectDatabase();
  const dishService = new DishService();
  const dishes = await dishService.searchDishes('chicken');
  console.log(`Seeded/updated ${dishes.length} dishes`);
  process.exit(0);
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
