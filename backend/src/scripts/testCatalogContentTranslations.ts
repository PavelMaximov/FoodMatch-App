import assert from 'node:assert/strict';
import { mapCatalogDish } from '../infrastructure/postgres/repositories/PostgresCatalogRepositories';
import { toDishDto } from '../modules/dishes/dto/dishDto';
import { contentSearchText, readDishContentTranslations } from '../modules/dishes/dto/dishContentTranslations';
const row = {
  id: 'stable-id', name: 'Rice', description: 'Simple rice', cuisine: 'german', is_custom: false,
  ingredient_components: [{ ingredientName: 'rice', quantity: '100', unit: 'g' }],
  steps: [{ step: 1, text: 'Cook for 10 minutes.' }],
  content_translations: { de: { sourceHash: 'private-import-metadata', strings: {
    Rice: 'Reis', 'Simple rice': 'Einfacher Reis', rice: 'Reis',
    'Cook for 10 minutes.': '10 Minuten kochen.',
  } } },
};
const mapped = mapCatalogDish(row, { logIngredients: false });
const dto = toDishDto(mapped)!;
assert.equal(dto.id, 'stable-id');
assert.equal(dto.name, 'Rice');
assert.equal(dto.cuisine, 'german');
assert.deepEqual(dto.ingredients, ['100 g rice']);
assert.equal(dto.contentTranslations?.de?.['100 g rice'], '100 g Reis');
assert.equal(dto.contentTranslations?.de?.['Cook for 10 minutes.'], '10 Minuten kochen.');
assert.equal(JSON.stringify(dto).includes('private-import-metadata'), false);
assert.ok(contentSearchText(mapped).includes('reis'));
assert.ok(contentSearchText(mapped).includes('rice'));
assert.equal(toDishDto({ ...mapped, steps: [] })!.contentTranslations?.de?.['Cook for 10 minutes.'], undefined);
for (const flag of [{ is_custom: true }, { isCustom: true }, { sourceType: 'custom' }]) {
  assert.equal(readDishContentTranslations({ ...row, ...flag }), undefined);
}
assert.equal(readDishContentTranslations({}), undefined);
assert.equal(readDishContentTranslations({ content_translations: { de: { strings: [] } } }), undefined);
assert.deepEqual(Object.keys(readDishContentTranslations({ content_translations: { de: {
  strings: JSON.parse('{"__proto__":"bad","Rice":"Reis","empty":"","invalid":3}'),
} } })!.de!), ['Rice']);
console.log('PASS catalog translation contract, identity, quantities, search, compact DTO, custom and legacy fallback');
