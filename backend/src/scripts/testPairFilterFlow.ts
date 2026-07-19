import { noStore } from '../core/middleware/noStore';
import { normalizeCoupleFilterStatePayload } from '../modules/couples/services/coupleService';
import { updateCoupleFilterStateSchema } from '../modules/couples/dto/coupleSchemas';
import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const direct = normalizeCoupleFilterStatePayload({
  cuisines: ['American', ' eastern eu ', 'German', 'american'],
  moods: ['Comfort'],
  diet: [],
  exclusions: ['no_nuts']
});
assert(JSON.stringify(direct.cuisines) === JSON.stringify(['american', 'eastern eu', 'german']), 'Direct payload should preserve normalized cuisines.');
assert(JSON.stringify(direct.moods) === JSON.stringify(['comfort']), 'Direct payload should preserve normalized moods.');
assert(JSON.stringify(direct.exclusions) === JSON.stringify(['no_nuts']), 'Direct payload should preserve normalized exclusions.');

const nested = normalizeCoupleFilterStatePayload({
  choices: {
    cuisines: ['American', 'German'],
    moods: ['Comfort'],
    diet: [],
    exclusions: ['no_nuts']
  }
});
assert(JSON.stringify(nested.cuisines) === JSON.stringify(['american', 'german']), 'Nested choices payload should be supported.');
const filterWrapped = normalizeCoupleFilterStatePayload({
  filter: { cuisines: ['American'], moods: ['Quick'], diet: [], exclusions: ['no_seafood', 'no_nuts'] }
});
assert(JSON.stringify(filterWrapped.exclusions) === JSON.stringify(['no_seafood', 'no_nuts']), 'filter payload should preserve exclusions.');
const filtersWrapped = normalizeCoupleFilterStatePayload({
  filters: { cuisines: ['German'], moods: ['Comfort'], diet: [], exclusions: ['no_dairy'] }
});
assert(JSON.stringify(filtersWrapped.cuisines) === JSON.stringify(['german']), 'filters payload should preserve cuisines.');
assert(updateCoupleFilterStateSchema.safeParse({ choices: { cuisines: ['American'], moods: ['Comfort'], diet: [], exclusions: ['no_nuts'] } }).success, 'Schema should accept nested choices payload.');
assert(updateCoupleFilterStateSchema.safeParse({ filter: { cuisines: ['American'], moods: ['Quick'], diet: [], exclusions: ['no_nuts'] } }).success, 'Schema should accept filter payload.');
assert(updateCoupleFilterStateSchema.safeParse({ filters: { cuisines: ['German'], moods: ['Comfort'], diet: [], exclusions: ['no_dairy'] } }).success, 'Schema should accept filters payload.');
assert(updateCoupleFilterStateSchema.safeParse({ cuisines: ['American'], moods: ['Comfort'], diet: [], exclusions: ['no_nuts'] }).success, 'Schema should accept direct choices payload.');

const req = { headers: { 'if-none-match': 'abc', 'if-modified-since': 'yesterday' } } as any;
const headers: Record<string, string> = {};
const res = { set(values: Record<string, string>) { Object.assign(headers, values); } } as any;
let nextCalled = false;
noStore(req, res, () => { nextCalled = true; });
assert(nextCalled, 'noStore should call next.');
assert(req.headers['if-none-match'] === undefined && req.headers['if-modified-since'] === undefined, 'noStore should strip conditional cache headers.');
assert(headers['Cache-Control']?.includes('no-store'), 'noStore should set Cache-Control no-store.');
assert(headers.Pragma === 'no-cache' && headers.Expires === '0' && headers['Surrogate-Control'] === 'no-store', 'noStore should set no-cache compatibility headers.');

const preSwipeProvider = readFileSync('../food_match/lib/features/swipes/logic/pre_swipe_provider.dart', 'utf8');
const preSwipeScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/pre_swipe_filter_screen.dart', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
const swipeProvider = readFileSync('../food_match/lib/features/swipes/logic/swipe_provider.dart', 'utf8');
assert(preSwipeProvider.includes('prepareCanonicalPairDeck'), 'Pair flow should use canonical-only backend deck preparation.');
assert(preSwipeScreen.includes('Could not load the shared deck. Please try again.'), 'Pair prepare errors should show a safe retry/error state.');
assert(!preSwipeScreen.includes('Could not prepare shared deck. Using local fallback for now.'), 'Pair screen must not expose local fallback copy.');
assert(swipesScreen.includes('pair_deck_error_retry'), 'Pair deck error retry should use canonical Pair deck loading.');
assert(swipesScreen.includes('canonical load retry attempt'), 'Pair deck loading should retry transient empty/not-ready states before showing final error.');
assert(swipesScreen.includes('Preparing your shared deck'), 'Pair deck loading should show loading copy before final error.');
assert(swipeProvider.includes('blocked generic loadDeck in Pair mode'), 'Generic deck loading should be guarded in Pair mode.');

const coupleRoutes = readFileSync('src/modules/couples/routes/coupleRoutes.ts', 'utf8');
for (const route of ["router.get('/me'", "router.get('/filter-state'", "router.put('/filter-state/me'", "router.post('/filter-state/confirm'", "router.post('/deck/prepare'", "router.get('/deck'"]) {
  const line = coupleRoutes.split('\n').find((candidate) => candidate.includes(route));
  assert(line?.includes('noStore'), `Expected noStore on couples route ${route}`);
}
const soloRoutes = readFileSync('src/modules/solo-swipes/routes/soloSwipeRoutes.ts', 'utf8');
assert(soloRoutes.split('\n').find((line) => line.includes("router.get('/active'"))?.includes('noStore'), 'Expected noStore on solo active route.');
const swipeRoutes = readFileSync('src/modules/swipes/routes/swipeRoutes.ts', 'utf8');
assert(swipeRoutes.split('\n').find((line) => line.includes("router.get('/matches'"))?.includes('noStore'), 'Expected noStore on matches route.');

console.log('Pair filter flow assertions passed.');
