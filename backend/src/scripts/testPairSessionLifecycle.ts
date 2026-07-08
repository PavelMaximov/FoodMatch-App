import { readFileSync } from 'fs';
import { Types } from 'mongoose';
import { buildPairKey, normalizeFilterList } from '../modules/filters/services/lastFilterPresetService';
import { LastFilterPresetModel } from '../modules/filters/models/LastFilterPreset';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const userA = new Types.ObjectId().toString();
const userB = new Types.ObjectId().toString();
const pairKey = buildPairKey([userB, userA]);
assert(pairKey === [userA, userB].sort().join('_'), 'Pair key should be sorted and stable for both users.');
assert(pairKey === buildPairKey([userA, userB]), 'Both users should share the same pairKey.');
assert(JSON.stringify(normalizeFilterList([' Italian ', 'italian', 'Light'])) === JSON.stringify(['italian', 'light']), 'Filter values should normalize and dedupe.');

const indexes = LastFilterPresetModel.schema.indexes();
const pairedIndex = indexes.find(([fields, options]) =>
  fields.mode === 1 && fields.userId === 1 && fields.pairKey === 1 && options?.unique === true
);
assert(pairedIndex, 'Paired last filter presets should be uniquely scoped by mode + userId + pairKey.');
const obsoletePairOnlyUniqueIndex = indexes.find(([fields, options]) =>
  fields.mode === 1 && fields.pairKey === 1 && fields.userId === undefined && options?.unique === true
);
assert(!obsoletePairOnlyUniqueIndex, 'Paired presets must not keep a unique mode + pairKey-only index.');

const lastFilterService = readFileSync('src/modules/filters/services/lastFilterPresetService.ts', 'utf8');
assert(lastFilterService.includes('userId: new Types.ObjectId(userId), pairKey: buildPairKey'), 'Paired preset scope should include current userId and pairKey.');
assert(!lastFilterService.includes('return LastFilterPresetModel.findOne({ mode, userId: null'), 'Legacy paired presets must not be returned as the prefill preset.');
assert(lastFilterService.includes('hasLegacyPairedPreset'), 'Legacy paired presets should only be exposed as availability metadata.');
assert(!lastFilterService.includes('return { mode, pairKey:'), 'Paired preset scope must not omit userId.');

const coupleService = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
assert(coupleService.includes("'PAIR_SESSION_INACTIVE'"), 'Couple service should expose a stable inactive pair session code.');
assert(coupleService.includes("session.status = 'closed'"), 'Leaving a pair should close the old session for the remaining partner.');

const coupleDeckService = readFileSync('src/modules/couples/services/coupleDeckService.ts', 'utf8');
assert(coupleDeckService.includes("'PAIR_SESSION_INACTIVE'"), 'Pair deck endpoints should reject inactive sessions with a stable code.');

const filterRoutes = readFileSync('src/modules/filters/routes/lastFilterPresetRoutes.ts', 'utf8');
assert(filterRoutes.split('\n').find((line) => line.includes("router.get('/last'"))?.includes('noStore'), 'Last filter GET should be no-store.');
assert(filterRoutes.split('\n').find((line) => line.includes("router.put('/last'"))?.includes('noStore'), 'Last filter PUT should be no-store.');

const coupleProvider = readFileSync('../food_match/lib/features/couple/logic/couple_provider.dart', 'utf8');
assert(coupleProvider.includes('Your partner has left this session. Please start or join a new session.'), 'Provider should expose the English partner-left message.');
assert(coupleProvider.includes('_handleSessionEndedIfNeeded'), 'Provider should clear stale pair state when the session disappears.');

const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
assert(swipesScreen.includes('Session ended'), 'Swipes screen should show an English session-ended dialog title.');
assert(swipesScreen.includes('Your partner has left this session. You can start a new session or join another one.'), 'Swipes screen should show the English session-ended dialog body.');
assert(swipesScreen.includes('clearSessionEndedMessage'), 'Swipes screen should consume the session-ended event once.');

console.log('Pair session lifecycle assertions passed.');
