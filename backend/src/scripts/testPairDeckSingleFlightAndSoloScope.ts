import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(__dirname, '..');
const compact = (value: string) =>
  value.replace(/\s+/g, '').replace(/,([)\]}])/g, '$1');
const source = (value: string) => ({
  includes: (needle: string) => compact(value).includes(compact(needle)),
});
const pairService = source(
  fs.readFileSync(
    path.join(root, 'modules/couples/services/coupleDeckService.ts'),
    'utf8',
  ) +
    fs.readFileSync(
      path.join(root, 'modules/couples/domain/pairDeckPolicy.ts'),
      'utf8',
    ),
);
const swipeService = source(
  fs.readFileSync(
    path.join(root, 'modules/matches/services/matchQueryService.ts'),
    'utf8',
  ),
);
const repository = fs.readFileSync(
  path.join(
    root,
    'infrastructure/postgres/repositories/PostgresMatchRepository.ts',
  ),
  'utf8',
);
const preSwipe = fs.readFileSync(
  path.resolve(
    root,
    '../../food_match/lib/features/swipes/logic/pre_swipe_provider.dart',
  ),
  'utf8',
);
const matchProvider = fs.readFileSync(
  path.resolve(
    root,
    '../../food_match/lib/features/matches/logic/match_provider.dart',
  ),
  'utf8',
);
const cacheService = fs.readFileSync(
  path.resolve(root, '../../food_match/lib/data/local/cache_service.dart'),
  'utf8',
);
const controller = fs.readFileSync(
  path.join(root, 'modules/swipes/controllers/swipeController.ts'),
  'utf8',
);

assert(
  pairService.includes('prepareFlights.get(key)') &&
    pairService.includes('return existing'),
);
assert(
  pairService.includes('withPostgresAdvisoryLock'),
  'concurrent app instances must serialize pair preparation',
);
assert(pairService.includes("scoringVersion:'weighted_category_cuisine_v1'"));
assert(pairService.includes("sessionId:String(input.id??input._id??'')"));
assert(
  pairService.includes(
    'loadLightweightDishesInPostgresOrder(s.preparedDeckDishIds)',
  ),
);
assert(preSwipe.includes('canonical pair deck prepare joined existing future'));
assert(
  !preSwipe.includes(
    'final PreparedDeck canonical = await _coupleRepository.getPreparedDeck()',
  ),
);
assert(
  swipeService.includes(
    'matches.listForSoloSession(userId,resolvedSoloSessionId)',
  ),
);
assert(repository.includes('w.solo_session_id=$2'));
assert(
  repository.includes('w.user_id=m.user_id'),
  'Solo match query must be user scoped',
);
assert(
  matchProvider.includes('matches:user=$user:mode=solo:scope=current:session='),
);
assert(
  matchProvider.includes(
    'matches:user=$user:mode=paired:scope=current:session=',
  ),
);
assert(matchProvider.includes('stale response ignored'));
assert(
  cacheService.includes("snapshot['scope'] != scopeKey"),
  'cache scope mismatch must never fall through',
);
assert(
  controller.includes('[Matches] request user=') &&
    controller.includes('[Matches] result count='),
);
console.log(
  'Pair single-flight and Solo match-scope regression checks passed.',
);
