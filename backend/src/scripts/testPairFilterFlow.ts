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
assert(updateCoupleFilterStateSchema.safeParse({ choices: { cuisines: ['American'], moods: ['Comfort'], diet: [], exclusions: ['no_nuts'] } }).success, 'Schema should accept nested choices payload.');
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
