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

assert(
  solo.includes('const shuffledTail = shuffleWithinScoreBands'),
  'Solo should shuffle the recommendation tail before prefixing custom dishes.'
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
  pair.indexOf('shuffleWithinScoreBands(result.dishes') <
    pair.indexOf('buildCustomFirstPairDeck('),
  'Pair should shuffle recommendations before adding the custom prefix.'
);
assert(
  pair.includes('return [...customPrefix, ...tail]'),
  'Pair persisted deck must place the interleaved custom prefix first.'
);
assert(
  dto.includes("raw.isCustom === true || raw.sourceType === 'custom'"),
  'Dish DTO custom detection should match backend prefix eligibility.'
);

console.log('[CustomFirstOrdering] static assertions passed');
