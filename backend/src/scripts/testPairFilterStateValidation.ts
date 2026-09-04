import assert from 'node:assert/strict';
import { updateCoupleFilterStateSchema } from '../modules/couples/dto/coupleSchemas';

function parse(payload: unknown) {
  const result = updateCoupleFilterStateSchema.safeParse(payload);
  assert(result.success, result.success ? '' : JSON.stringify(result.error.flatten()));
  return result.data;
}

assert.deepEqual(parse({ selectedCategories: ['Everyday', 'everyday'], selectedCuisines: ['IT'] }).selectedCategories, ['everyday']);
assert.deepEqual(parse({ dishRegisters: ['home_classic'], cuisines: ['Italian'] }).selectedCategories, ['home_classic']);
assert.deepEqual(parse({ category: 'celebration', cuisine: 'Italian' }).selectedCategories, ['celebration']);
assert.deepEqual(parse({ includeCustomDishesFirst: true, selectedCategories: [], cuisines: [] }).selectedCategories, ['custom']);

for (const payload of [
  { selectedCategories: [] },
  { selectedCategories: ['one', 'two', 'three', 'four'] },
  { selectedCategories: ['custom', 'everyday'] },
]) {
  const result = updateCoupleFilterStateSchema.safeParse(payload);
  assert(!result.success);
  const details = result.error.flatten().fieldErrors;
  assert(details.selectedCategories?.length, 'validation must identify selectedCategories');
}

console.log('Pair filter-state validation regression checks passed.');
