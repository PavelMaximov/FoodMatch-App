import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(__dirname, '..');
const read = (relative: string) => fs.readFileSync(path.join(root, relative), 'utf8');

const service = read('modules/couples/services/coupleService.ts');
const schemas = read('modules/couples/dto/coupleSchemas.ts');
const coupleRoutes = read('modules/couples/routes/coupleRoutes.ts');
const soloRoutes = read('modules/solo-swipes/routes/soloSwipeRoutes.ts');
const swipeRoutes = read('modules/swipes/routes/swipeRoutes.ts');
const noStore = read('core/middleware/noStore.ts');

assert.match(schemas, /choices: filterChoicesSchema\.optional\(\)/, 'PUT filter-state accepts nested choices payloads');
assert.match(service, /const choices = this\.normalizeChoices\(payload\)/, 'update normalizes payload shape before saving');
assert.match(service, /entry\.confirmed = false/, 'changing choices marks the current user unconfirmed');
assert.match(service, /clearPreparedDeck\(session\)/, 'changing choices clears prepared deck');
assert.match(service, /entry\.confirmed = true/, 'confirm endpoint sets current user confirmed');
assert.doesNotMatch(service, /confirmMyFilterState[\s\S]*entry\.cuisines = \[\]/, 'confirm does not reset cuisines');
assert.match(service, /partnerChoices: partnerEntry/, 'response includes user-relative partner choices');
assert.match(service, /partnerPresent: memberCount >= 2/, 'response includes partner presence metadata');
assert.match(noStore, /no-store, no-cache, must-revalidate, proxy-revalidate/, 'no-store cache-control is configured');
assert.match(noStore, /res\.removeHeader\('ETag'\)/, 'dynamic responses remove ETag');
for (const route of [coupleRoutes, soloRoutes, swipeRoutes]) {
  assert.match(route, /noStore/, 'dynamic route installs noStore middleware');
}
console.log('Pair filter flow static assertions passed');
