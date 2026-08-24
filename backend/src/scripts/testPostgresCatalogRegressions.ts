import assert from 'assert';
import { AppError } from '../core/errors/AppError';
import { UserSavedDishRepository } from '../domain/repositories/UserSavedDishRepository';
import {
  CatalogDish,
  customDishImageUrl,
  customDishSource,
  mapCatalogDish,
} from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { toDishDto } from '../modules/dishes/dto/dishDto';
import { UserSavedDishService } from '../modules/users/services/userSavedDishService';

const dish = mapCatalogDish({
  id: '11111111-1111-4111-8111-111111111111',
  legacy_mongo_id: 'legacy-dish',
  name: 'Test dish',
  description: 'Catalog fixture',
  image_url: 'https://example.invalid/dish.jpg',
  cuisine: 'Test',
  type: 'Dinner',
  mood: [], diet: [], source: ['catalog'], season: [], popular: false,
  ingredients: ['First ingredient', 'Second ingredient'],
  steps: [{ step: 1, text: 'First step' }, { step: 2, text: 'Second step' }],
  created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
});

class MemorySavedDishes implements UserSavedDishRepository {
  readonly rows = new Set<string>();
  async save(userId: string, dishId: string) { this.rows.add(`${userId}:${dishId}`); }
  async remove(userId: string, dishId: string) { return this.rows.delete(`${userId}:${dishId}`); }
  async listDishIds(userId: string) {
    return [...this.rows].filter((row) => row.startsWith(`${userId}:`)).map((row) => row.slice(userId.length + 1));
  }
  async isSaved(userId: string, dishId: string) { return this.rows.has(`${userId}:${dishId}`); }
}

const dishes = {
  async getByPublicId(id: string): Promise<CatalogDish | null> {
    return id === String(dish.id) || id === dish.sourceId ? dish : null;
  },
  async getByIds(ids: string[]) { return ids.includes(String(dish.id)) ? [dish] : []; },
};

async function run() {
  const saved = new MemorySavedDishes();
  const service = new UserSavedDishService(saved, dishes);
  const user = '22222222-2222-4222-8222-222222222222';
  await service.addSavedDish(user, 'legacy-dish');
  await service.addSavedDish(user, 'legacy-dish');
  assert.equal(saved.rows.size, 1, 'saving twice must be idempotent');
  const favorites = await service.listSavedDishes(user);
  assert.equal(favorites.length, 1);
  assert.deepEqual(favorites[0].ingredients, ['First ingredient', 'Second ingredient']);
  assert.deepEqual(favorites[0].steps.map((step) => step.step), [1, 2]);
  await service.removeSavedDish(user, String(dish.id));
  assert.equal((await service.listSavedDishes(user)).length, 0);

  await assert.rejects(
    () => service.addSavedDish(user, 'missing'),
    (error: unknown) => error instanceof AppError && error.code === 'SAVED_DISH_DISH_NOT_FOUND',
  );

  const customDto = toDishDto({
    ...dish,
    id: '33333333-3333-4333-8333-333333333333',
    imageUrl: customDishImageUrl(undefined),
    image_url: '',
    source: customDishSource([]),
    isCustom: true,
  });
  assert(customDto);
  assert.equal(customDto.imageUrl, '');
  assert(customDto.source.includes('user'), 'empty image plus source=user activates the Flutter local placeholder');
  console.log('PASS saved dishes, relational ingredients, ordered steps, and custom image fallback');
}

run().catch((error) => { console.error(error); process.exit(1); });
