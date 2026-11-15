'use strict';
const assert = require('node:assert/strict');
const path = require('node:path');
const {loadSources, calculateRecipe, volumeMass, resolveFood} = require('./calculateNutrition');
const {loadManifest, validate} = require('./renderPatch');
const folder = path.resolve(__dirname, '../../data/catalog-standardization/2026-11-14');
const sources = loadSources();
const manifest = loadManifest(folder);

// Independent arithmetic fixture: 100 g sugar, 20 ml oil at 0.9 g/ml, two servings.
// Imperial quantities describe the same ingredients and must not be added again.
const fixtureSources = {
  revision: 'fixture',
  assumptions: {recipeOverrides: {}, defaultIngredientOverrides: {}, volumeConversions: {oil: {gramsPerMl: 0.9}}},
  mappings: {sugar: {reference: 'sugar'}, oil: {reference: 'oil'}},
  references: {foods: {
    sugar: {per100g: {calories: 400, protein: 0, fat: 0, carbohydrates: 100, fiber: 0, sugar: 100, sodium: null}},
    oil: {per100g: {calories: 900, protein: 0, fat: 100, carbohydrates: 0, fiber: 0, sugar: 0, sodium: 0}},
  }},
};
const state = {
  dish: {id: 'fixture', num_servings: 2},
  components: [{id: 's', position: 0, ingredient_name: 'sugar'}, {id: 'o', position: 1, ingredient_name: 'oil'}],
  measurements: [
    {component_id: 's', quantity: 100, unit: 'g', system: 'metric'},
    {component_id: 's', quantity: 3.53, unit: 'oz', system: 'imperial'},
    {component_id: 'o', quantity: 20, unit: 'ml', system: 'metric'},
  ],
};
const r = calculateRecipe('fixture', state, fixtureSources);
assert.equal(r.unroundedCalories, 281);
assert.equal(r.nutrition.calories, 280);
assert.equal(r.nutrition.fat, 9);
assert.equal(r.nutrition.carbohydrates, 50);
assert.equal(r.nutrition.sodium, null, 'missing reference must not become zero');
assert.equal(r.nutrition.estimated, true);
assert.equal(r.nutrition.basis, 'per_serving');
assert.equal(calculateRecipe('fixture', {...state, measurements: state.measurements.filter(m => m.system !== 'imperial')}, fixtureSources).unroundedCalories, 281);
assert.throws(() => calculateRecipe('fixture', {...state, dish: {num_servings: 0}}, fixtureSources), /servings/);
assert.throws(() => calculateRecipe('fixture', {...state, measurements: [...state.measurements, state.measurements[0]]}, fixtureSources), /one metric/);
assert.throws(() => volumeMass('unmapped', 1, {}, sources), /density/);
assert.throws(() => volumeMass('olive oil', 1, {references: ['wrong']}, sources), /does not belong/);
assert.throws(() => resolveFood('new unknown ingredient', null, sources), /Unmapped/);
console.log('PASS independent arithmetic, units, missing nutrients and input validation');

validate(manifest);
const find = name => manifest.patches.find(p => p.name === name);
const falafel = calculateRecipe('Falafel', find('Falafel').after, sources);
assert.equal(falafel.ingredients.find(i => i.name === 'sunflower oil').edibleGrams, 45);
assert.ok(falafel.nutrition.oilSensitivityKcal.low < falafel.nutrition.calories);
assert.ok(falafel.nutrition.oilSensitivityKcal.high > falafel.nutrition.calories);
const schnitzel = calculateRecipe('Schnitzel with Potato Salad', find('Schnitzel with Potato Salad').after, sources);
assert.equal(schnitzel.ingredients.find(i => i.name === 'flour').edibleGrams, 20);
assert.equal(schnitzel.ingredients.find(i => i.name === 'sunflower oil').edibleGrams, 33.796);
const changed = structuredClone(manifest);
changed.patches[0].after.dish.nutrition.calories += 5;
assert.throws(() => validate(changed), /reproducible/);
changed.patches = manifest.patches;
changed.nutritionReferenceRevision = 'stale';
assert.throws(() => validate(changed), /reference revision/);
console.log('PASS all 34 calculations, retained oil/coating, nutrition tampering and stale references');
