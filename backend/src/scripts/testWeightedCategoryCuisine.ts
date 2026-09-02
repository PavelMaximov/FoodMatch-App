import assert from 'assert';
import {
  buildPairSharedRecommendedDeck,
  buildRecommendedDeck,
  categoryScore,
  cuisineScore,
  SCORING_VERSION,
  weightedPreferenceScore
} from '../modules/recommendations/deckRecommendationService';

const dish = (id: string, overrides: Record<string, unknown> = {}) => ({
  _id: id, id, name: id, cuisine: 'italian', dishRegister: 'everyday_staple',
  mood: [], diet: ['vegan'], ingredients: ['tomato'], source: [], season: [],
  popular: false, ...overrides
} as any);
const filters = (overrides: Record<string, unknown> = {}) => ({
  selectedCategories: ['everyday'], dishRegisters: ['everyday'], cuisines: ['italian'],
  moods: [], diet: [], exclusions: [], ...overrides
} as any);

assert.equal(SCORING_VERSION, 'weighted_category_cuisine_v1');
assert.equal(categoryScore(dish('exact'), ['everyday', 'special_occasion']), 1);
assert.equal(categoryScore(dish('neighbor', { dishRegister: 'home_classic' }), ['everyday']), 0.5);
assert.equal(categoryScore(dish('popular', { dishRegister: 'unknown', popular: true }), ['everyday']), 0.1);
assert.equal(categoryScore(dish('custom', { isCustom: true }), ['everyday']), 0);
assert.equal(cuisineScore(dish('exact'), ['IT']), 1);
assert.equal(cuisineScore(dish('cluster', { cuisine: 'greek' }), ['italian']), 0.6);
assert.equal(cuisineScore(dish('other', { cuisine: 'japanese' }), ['italian']), 0.2);
assert.equal(weightedPreferenceScore(dish('weighted'), filters(), 1), 1);

const catalog = Array.from({ length: 12 }, (_, i) => dish(`safe-${i}`));
catalog.push(dish('blocked-ingredient', { ingredients: ['peanut'] }), dish('blocked-id'));
const solo = buildRecommendedDeck({ userId: 'u', dishes: catalog, filters: filters({ exclusions: ['no_nuts'] }),
  excludedDishIds: new Set(['blocked-id']), deckSize: 30, mode: 'solo' });
assert(!solo.dishes.some((item) => item.id === 'blocked-ingredient' || item.id === 'blocked-id'));
assert.equal(solo.meta.availableCount, 12);

const pair = buildPairSharedRecommendedDeck({ users: [
  { userId: 'a', filters: filters({ selectedCategories: ['everyday'], cuisines: ['italian'] }) },
  { userId: 'b', filters: filters({ selectedCategories: ['special_occasion'], cuisines: ['greek'] }) }
], dishes: catalog, hardFilters: filters({ exclusions: ['no_nuts'] }), excludedDishIds: new Set(['blocked-id']), deckSize: 30 });
assert(!pair.dishes.some((item) => item.id === 'blocked-ingredient' || item.id === 'blocked-id'));
assert.equal(pair.meta.commonPool, true);

const tiny = buildRecommendedDeck({ userId: 'u', dishes: [dish('one')], filters: filters({ exclusions: ['no_nuts'] }), deckSize: 10, mode: 'solo' });
assert.equal(tiny.meta.expansionApplied, true);
assert.equal(tiny.meta.expansionLevel, 'critical');
console.log('Weighted category/cuisine recommendation tests passed');
