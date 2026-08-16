import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const solo = readFileSync(
  'src/modules/solo-swipes/services/soloSwipeService.ts',
  'utf8'
);
const pair = readFileSync(
  'src/modules/couples/services/coupleDeckService.ts',
  'utf8'
);
const dto = readFileSync('src/modules/dishes/dto/dishDto.ts', 'utf8');
const recommendation = readFileSync(
  'src/modules/recommendations/deckRecommendationService.ts',
  'utf8'
);
const swipeProvider = readFileSync(
  '../food_match/lib/features/swipes/logic/swipe_provider.dart',
  'utf8'
);
const preSwipeProvider = readFileSync(
  '../food_match/lib/features/swipes/logic/pre_swipe_provider.dart',
  'utf8'
);

assert(
  !solo.includes('shuffleWithinScoreBands') && !solo.includes('randomUUID'),
  'Solo must not randomize the score-sorted recommendation tail.'
);
assert(
  solo.includes('dishes: [...customPrefix, ...tail]'),
  'Solo persisted deck must place the custom prefix before the normal tail.'
);
assert(
  solo.includes("dish.sourceType === 'custom'"),
  'Solo should recognize legacy sourceType custom dishes.'
);
assert(
  !pair.includes('shuffleWithinScoreBands') && !pair.includes('randomUUID'),
  'Pair must not randomize recommendations before adding the custom prefix.'
);
assert(
  pair.includes('return [...customPrefix, ...tail]'),
  'Pair persisted deck must place the interleaved custom prefix first.'
);
assert(
  dto.includes("raw.isCustom === true || raw.sourceType === 'custom'"),
  'Dish DTO custom detection should match backend prefix eligibility.'
);
assert(
  recommendation.includes('const items = scored.slice(0, deckSize)') &&
    !recommendation.includes('weightedPick') &&
    !recommendation.includes('seededRandom'),
  'Normal tails must remain deterministically sorted by recommendation score.'
);
assert(
  pair.includes('compareCustomByPreferences') &&
    solo.includes('compareCustomByPreferences'),
  'Solo and Pair custom prefixes must use deterministic preference ordering.'
);
assert(
  !preSwipeProvider.toLowerCase().includes('shuffle') &&
    !preSwipeProvider.includes('_SeededRandom'),
  'Flutter pre-swipe fallback must not reorder scored backend-style results.'
);
assert(
  swipeProvider.includes('[DeckApply] mode=solo source=backend') &&
    swipeProvider.includes('[DeckApply] mode=pair source=preparedDeck'),
  'Flutter should log and apply backend deck order directly.'
);

console.log('[CustomFirstOrdering] static assertions passed');
