import { Types } from 'mongoose';
import { buildPairSharedRecommendedDeck } from '../modules/recommendations/deckRecommendationService';
import { DishDocument } from '../modules/dishes/models/Dish';

function dish(overrides: Partial<DishDocument> & { name: string; cuisine: string; ingredients?: string[]; diet?: string[]; mood?: string[] }) {
  return {
    _id: new Types.ObjectId(),
    name: overrides.name,
    description: '',
    imageUrl: '',
    cuisine: overrides.cuisine,
    type: 'main',
    mood: overrides.mood ?? [],
    diet: overrides.diet ?? [],
    ingredients: overrides.ingredients ?? [],
    cookTime: 30,
    calories: '',
    effort: 'easy',
    source: [],
    servings: '',
    season: [],
    popular: overrides.popular ?? false,
    steps: [],
    status: 'approved',
    visibility: overrides.visibility ?? 'public',
    isCustom: overrides.isCustom ?? false,
    coupleId: overrides.coupleId
  } as unknown as DishDocument;
}

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const userA = new Types.ObjectId().toString();
const userB = new Types.ObjectId().toString();
const coupleId = new Types.ObjectId();

const italian = dish({ name: 'Italian Pasta', cuisine: 'Italian', ingredients: ['tomato'], diet: ['vegetarian'], mood: ['light'] });
const german = dish({ name: 'German Stew', cuisine: 'German', ingredients: ['potato'], diet: ['vegetarian'], mood: ['filling'] });
const french = dish({ name: 'French Salad', cuisine: 'French', ingredients: ['greens'], diet: ['vegan'], mood: ['fresh'] });
const spanish = dish({ name: 'Spanish Beans', cuisine: 'Spanish', ingredients: ['beans'], diet: ['vegan'], mood: ['fresh'] });
const greek = dish({ name: 'Greek Bowl', cuisine: 'Greek', ingredients: ['cucumber'], diet: ['vegetarian'], mood: ['fresh'] });
const thai = dish({ name: 'Thai Soup', cuisine: 'Thai', ingredients: ['lemongrass'], diet: ['vegan'], mood: ['fresh'] });
const nutDish = dish({ name: 'Pine Nut Salad', cuisine: 'Italian', ingredients: ['pine nuts'], diet: ['vegan'] });
const dairyDish = dish({ name: 'Milk Soup', cuisine: 'German', ingredients: ['milk'], diet: ['vegetarian'] });
const meatDish = dish({ name: 'Beef Plate', cuisine: 'American', ingredients: ['beef'], diet: [] });
const safeCustom = dish({ name: 'Safe Custom Dish', cuisine: 'Mexican', ingredients: ['beans'], diet: ['vegan'], isCustom: true, visibility: 'session', coupleId });
const excludedCustom = dish({ name: 'Custom Nut Dish', cuisine: 'Mexican', ingredients: ['pine nuts'], diet: ['vegan'], isCustom: true, visibility: 'session', coupleId });

const softCuisineResult = buildPairSharedRecommendedDeck({
  users: [
    { userId: userA, filters: { cuisines: ['italian'], moods: ['light'], diet: [], exclusions: [] } },
    { userId: userB, filters: { cuisines: ['german'], moods: ['filling'], diet: [], exclusions: [] } }
  ],
  dishes: [french, italian, german, spanish, greek, thai],
  hardFilters: { cuisines: ['italian', 'german'], moods: ['light', 'filling'], diet: [], exclusions: [] },
  deckSize: 10
});
assert(softCuisineResult.dishes.some((item) => item.name === 'French Salad'), 'Pair cuisine filters should not hard-exclude unrelated cuisines.');
assert(softCuisineResult.dishes.slice(0, 2).some((item) => item.name === 'Italian Pasta'), 'Italian choice should influence ranking.');
assert(softCuisineResult.dishes.slice(0, 2).some((item) => item.name === 'German Stew'), 'German choice should influence ranking.');

const exclusionUnionResult = buildPairSharedRecommendedDeck({
  users: [
    { userId: userA, filters: { cuisines: [], moods: [], diet: [], exclusions: ['no_nuts'] } },
    { userId: userB, filters: { cuisines: [], moods: [], diet: [], exclusions: ['no_dairy'] } }
  ],
  dishes: [italian, nutDish, dairyDish],
  hardFilters: { cuisines: [], moods: [], diet: [], exclusions: ['no_nuts', 'no_dairy'] },
  deckSize: 10
});
assert(!exclusionUnionResult.dishes.some((item) => item.name === 'Pine Nut Salad'), 'Pair exclusion union should remove nut dishes.');
assert(!exclusionUnionResult.dishes.some((item) => item.name === 'Milk Soup'), 'Pair exclusion union should remove dairy dishes.');

const veganResult = buildPairSharedRecommendedDeck({
  users: [
    { userId: userA, filters: { cuisines: [], moods: [], diet: ['vegan'], exclusions: [] } },
    { userId: userB, filters: { cuisines: [], moods: [], diet: [], exclusions: [] } }
  ],
  dishes: [french, italian, meatDish],
  hardFilters: { cuisines: [], moods: [], diet: ['vegan'], exclusions: [] },
  deckSize: 10
});
assert(veganResult.dishes.every((item) => item.diet.includes('vegan')), 'Either partner selecting vegan should force vegan dishes only.');

const customResult = buildPairSharedRecommendedDeck({
  users: [
    { userId: userA, filters: { cuisines: [], moods: [], diet: [], exclusions: ['no_nuts'] } },
    { userId: userB, filters: { cuisines: [], moods: [], diet: [], exclusions: [] } }
  ],
  dishes: [italian, safeCustom, excludedCustom],
  hardFilters: { cuisines: [], moods: [], diet: [], exclusions: ['no_nuts'] },
  customDishIds: new Set([safeCustom._id.toString(), excludedCustom._id.toString()]),
  deckSize: 10
});
assert(customResult.dishes[0].name === 'Safe Custom Dish', 'Safe custom/session dishes should receive a boost.');
assert(!customResult.dishes.some((item) => item.name === 'Custom Nut Dish'), 'Excluded custom/session dishes must not bypass exclusions.');
assert(customResult.meta.algorithm === 'weighted_scoring_pair_shared_mvp_v1', 'Pair deck should use the shared pair recommendation algorithm label.');

console.log('Pair recommendation assertions passed.');
