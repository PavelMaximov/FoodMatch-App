import assert from 'assert';
import { AppError } from '../core/errors/AppError';
import { UserSavedDishRepository } from '../domain/repositories/UserSavedDishRepository';
import {
  buildIngredientDisplayStrings,
  CatalogDish,
  customDishImageUrl,
  customDishSource,
  mapCatalogDish,
} from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { toDishDto } from '../modules/dishes/dto/dishDto';
import { UserSavedDishService } from '../modules/users/services/userSavedDishService';

const ingredientComponents = [
  { id: 'chicken', rawText: 'chicken breast', quantity: '500', unit: 'g', ingredientName: 'chicken breast' },
  { id: 'salt-raw', rawText: 'Salt, to taste', quantity: '1', unit: 'tsp', ingredientName: 'salt' },
  { id: 'rice', quantity: '1', unit: 'cup', ingredientName: 'rice' },
  { id: 'salt-measured', quantity: '0.5', unit: 'tsp', ingredientName: 'salt' },
  { id: 'parsley', ingredientName: 'Parsley' },
  { id: 'oil-display', rawText: '2 tbsp', quantity: '2', unit: 'tbsp', displaySingular: 'olive oil' },
];
const expectedIngredients = [
  '500 g chicken breast',
  'Salt, to taste',
  '1 cup rice',
  '0.5 tsp salt',
  'Parsley',
  '2 tbsp olive oil',
];

assert.deepEqual(
  buildIngredientDisplayStrings('fixture', ingredientComponents),
  expectedIngredients,
  'ingredient display must prefer raw text, then measurements, then ingredient name, in input order',
);
assert(!expectedIngredients.includes('2 tbsp'), 'measurement-only output must not replace an available display name');

const dish = mapCatalogDish({
  id: '11111111-1111-4111-8111-111111111111', legacy_mongo_id: 'legacy-dish',
  name: 'Test dish', description: 'Catalog fixture', image_url: 'https://example.invalid/dish.jpg',
  cuisine: 'Test', type: 'Dinner', mood: [], diet: [], source: ['catalog'], season: [], popular: false,
  ingredient_components: ingredientComponents,
  steps: [{ step: 1, text: 'First step' }, { step: 2, text: 'Second step' }],
  created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
});

class MemorySavedDishes implements UserSavedDishRepository {
  readonly rows = new Set<string>();
  async save(userId: string, dishId: string) { this.rows.add(`${userId}:${dishId}`); }
  async remove(userId: string, dishId: string) { return this.rows.delete(`${userId}:${dishId}`); }
  async listDishIds(userId: string) { return [...this.rows].filter((row) => row.startsWith(`${userId}:`)).map((row) => row.slice(userId.length + 1)); }
  async isSaved(userId: string, dishId: string) { return this.rows.has(`${userId}:${dishId}`); }
}

const dishes = {
  async getByPublicId(id: string): Promise<CatalogDish | null> { return id === String(dish.id) || id === dish.sourceId ? dish : null; },
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
  assert.deepEqual(favorites[0].ingredients, expectedIngredients, 'saved dishes must return full ingredient displays');
  assert.deepEqual(favorites[0].steps.map((step) => step.step), [1, 2]);
  await service.removeSavedDish(user, String(dish.id));
  assert.equal((await service.listSavedDishes(user)).length, 0);
  await assert.rejects(() => service.addSavedDish(user, 'missing'),
    (error: unknown) => error instanceof AppError && error.code === 'SAVED_DISH_DISH_NOT_FOUND');

  const customDto = toDishDto(mapCatalogDish({ ...dish, id: '33333333-3333-4333-8333-333333333333',
    imageUrl: customDishImageUrl(undefined), image_url: '', source: customDishSource([]), isCustom: true,
    ingredient_components: [{ rawText: '2 large carrots', ingredientName: 'carrots' }] }));
  assert(customDto);
  assert.deepEqual(customDto.ingredients, ['2 large carrots']);
  assert.equal(customDto.imageUrl, '');
  assert(customDto.source.includes('user'));
  for (const key of ['id','name','description','imageUrl','cuisine','type','mood','diet','ingredients','cookTime','calories','effort','source','servings','season','popular','steps']) {
    assert(key in customDto, `public Dish DTO field missing: ${key}`);
  }
  console.log('PASS full ingredient displays, ordering, saved dishes, custom dishes, and public DTO compatibility');
}

run().catch((error) => { console.error(error); process.exit(1); });
