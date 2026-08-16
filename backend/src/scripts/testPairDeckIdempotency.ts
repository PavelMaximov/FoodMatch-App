import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const source = readFileSync('src/modules/couples/services/coupleDeckService.ts', 'utf8');
const model = readFileSync('src/modules/couples/models/CoupleSession.ts', 'utf8');
const preSwipeProvider = readFileSync('../food_match/lib/features/swipes/logic/pre_swipe_provider.dart', 'utf8');
const preSwipeScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/pre_swipe_filter_screen.dart', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
const swipeProvider = readFileSync('../food_match/lib/features/swipes/logic/swipe_provider.dart', 'utf8');

assert(model.includes("'preparing'"), 'Couple preparedDeck status should include preparing for generation locks.');
assert(source.includes('isReusablePreparedDeck'), 'Pair deck prepare should check for reusable preparedDeck before generation.');
assert(source.includes('reuse existing deck'), 'Pair deck prepare should log/reuse an existing same-hash ready deck.');
assert(source.includes("'preparedDeck.status': 'preparing'"), 'Pair deck prepare should mark preparing before generation.');
assert(source.includes('findOneAndUpdate'), 'Pair deck prepare should use an atomic update for the preparing lock.');
assert(source.includes("'DECK_PREPARING'"), 'Concurrent same-hash prepare should expose a stable DECK_PREPARING code.');
assert(source.includes('waitForPreparedDeck'), 'Concurrent prepare should wait/re-fetch the canonical prepared deck.');
assert(source.includes('loadPreparedDeckDishes'), 'Idempotent prepare should return persisted preparedDeck dishes.');
assert(source.includes("status: 'ready'"), 'Successful generation should persist a ready shared preparedDeck.');
assert(source.includes("status: 'failed'"), 'Failed generation should not leave the shared deck stuck preparing.');
assert(source.includes('buildPairSharedRecommendedDeck'), 'Pair v2 recommendation builder should still be used.');
assert(source.includes('customFirstUserIds: [...filters.customFirstUserIds].sort()'), 'Pair filtersHash should include the selected custom-first users.');
assert(source.includes('buildCustomFirstPairDeck'), 'Backend should own canonical custom-first Pair ordering.');
assert(!source.includes('shuffleWithinScoreBands'), 'Pair generation must not shuffle the score-sorted canonical order.');
assert(source.includes("recommendationAlgorithm: 'weighted_scoring_pair_shared_v2_deterministic_order_v1'"), 'Pair filtersHash should version deterministic ordering changes.');
assert(source.includes('sessionMemberIds: [...filters.sessionMemberIds].sort()'), 'Pair filtersHash should include canonical member identity.');
assert(source.includes('return [...customPrefix, ...tail]'), 'Pair final order must persist the custom prefix before the normal tail.');
assert(source.includes("dish.sourceType === 'custom'"), 'Legacy sourceType custom dishes must remain eligible for custom-first ordering.');
const swipeService = readFileSync('src/modules/swipes/services/swipeService.ts', 'utf8');
assert(swipeService.includes('dishIsInPreparedDeck'), 'Pair custom dishes should be swipeable when present in the canonical prepared deck.');
assert(source.includes('weighted_scoring_pair_shared_v2') || readFileSync('src/modules/recommendations/deckRecommendationService.ts', 'utf8').includes('weighted_scoring_pair_shared_v2'), 'Pair v2 algorithm label should remain available.');
assert(!source.includes('preparedDeckByUser'), 'No per-user pair prepared deck should be introduced.');
assert(!model.includes('preparedDeckByUser'), 'CoupleSession should still store one shared preparedDeck.');
assert(preSwipeProvider.includes('_loadCanonicalBackendDeck'), 'Frontend should reload the backend canonical deck after prepare.');
assert(preSwipeProvider.includes('getPreparedDeck'), 'Frontend should use GET /api/couples/deck as canonical source after prepare/preparing.');
assert(preSwipeProvider.includes('prepareCanonicalPairDeck'), 'Frontend Pair flow should expose a canonical-only preparedDeck loader.');
assert(preSwipeScreen.includes('prepareCanonicalPairDeck'), 'Pair pre-swipe should call the canonical preparedDeck loader.');
assert(!preSwipeScreen.includes('prepareBackendDeckWithFallback(localResult)'), 'Pair pre-swipe must not pass a local fallback deck into backend prepare.');
assert(!preSwipeScreen.includes('preSwipeProvider.prepare(\n        userId: userId,\n        coupleProvider: coupleProvider'), 'Pair pre-swipe should not build a local fallback deck before canonical prepare.');
assert(swipesScreen.includes('pre_swipe_closed_after_pair_ready'), 'Pair pre-swipe close path should retry canonical deck load when both confirmed.');
assert(swipesScreen.includes('empty pre-swipe result before both confirmed; no local Pair deck applied'), 'Empty Pair pre-swipe results should not apply local empty decks before both confirm.');
assert(swipeProvider.includes('blocked generic loadDeck in Pair mode'), 'Generic SwipeProvider.loadDeck should be blocked defensively in Pair mode.');

console.log('Pair deck idempotency assertions passed.');
