import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const source = readFileSync('src/modules/couples/services/coupleDeckService.ts', 'utf8');
const model = readFileSync('src/modules/couples/models/CoupleSession.ts', 'utf8');
const preSwipeProvider = readFileSync('../food_match/lib/features/swipes/logic/pre_swipe_provider.dart', 'utf8');

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
assert(source.includes('weighted_scoring_pair_shared_v2') || readFileSync('src/modules/recommendations/deckRecommendationService.ts', 'utf8').includes('weighted_scoring_pair_shared_v2'), 'Pair v2 algorithm label should remain available.');
assert(!source.includes('preparedDeckByUser'), 'No per-user pair prepared deck should be introduced.');
assert(!model.includes('preparedDeckByUser'), 'CoupleSession should still store one shared preparedDeck.');
assert(preSwipeProvider.includes('_loadCanonicalBackendDeck'), 'Frontend should reload the backend canonical deck after prepare.');
assert(preSwipeProvider.includes('getPreparedDeck'), 'Frontend should use GET /api/couples/deck as canonical source after prepare/preparing.');
assert(preSwipeProvider.includes('preparing'), 'Frontend should handle DECK_PREPARING response by polling/reloading.');

console.log('Pair deck idempotency assertions passed.');
