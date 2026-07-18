import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const invitationService = readFileSync('src/modules/couples/services/coupleInvitationService.ts', 'utf8');
const coupleService = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
const deckService = readFileSync('src/modules/couples/services/coupleDeckService.ts', 'utf8');
const packageJson = readFileSync('package.json', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
const coupleProvider = readFileSync('../food_match/lib/features/couple/logic/couple_provider.dart', 'utf8');
const swipeProvider = readFileSync('../food_match/lib/features/swipes/logic/swipe_provider.dart', 'utf8');

assert(packageJson.includes('test:pair-round-coordination'), 'package.json should expose pair round coordination assertions.');
assert(coupleService.includes('startPairRoundOnSession'), 'CoupleService should expose a shared Pair new-round coordinator helper.');
assert(invitationService.includes("reason: 'continuation'"), 'Continuation accept should use the shared Pair round coordinator.');
assert(coupleService.includes("reason: 'filter_change'"), 'Filter-change commit should use the shared Pair round coordinator.');
assert(invitationService.includes("status: { $in: ['pending', 'accepted'] }"), 'Continue-as-before should reuse one pending/accepted round per pairKey.');
assert(invitationService.includes('existingRound.toUserId.toString() === userId'), 'Reciprocal Continue as before should join/accept the existing round instead of creating a duplicate.');
assert(invitationService.includes("$set: { status: 'cancelled' }"), 'Accepting one continuation invite should cancel/supersede duplicate pending invites.');
assert(invitationService.includes("{ toUserId: objectId, status: 'accepted' }"), 'Accepted continuation state should be visible to the recipient through polling.');
assert(invitationService.includes('suppressed stale/same-round invite reason=active_pair_round'), 'Backend should suppress stale pending invites during active Pair rounds.');
assert(coupleProvider.includes('hasActivePairRoundInProgress'), 'Frontend should know when Pair rounds should suppress continuation invites.');
assert(coupleProvider.includes('acceptedInvite') && coupleProvider.includes('shouldOpenPreviousChoiceAfterInvite'), 'Accepted continuation state should converge clients to previous choice.');
assert(deckService.includes('PAIR_FILTER_CHANGE_IN_PROGRESS'), 'Deck restart should be blocked during partner_action_required filter changes.');
assert(coupleService.includes('PAIR_RESTART_IN_PROGRESS'), 'Filter-change commit should be blocked during restart waiting/ready states.');
assert(swipesScreen.includes('canonical load retry attempt'), 'Pair canonical deck loading should retry before final error.');
assert(swipesScreen.includes('Preparing your shared deck'), 'Pair deck loading should show loading copy before final error.');
assert(swipesScreen.includes('WillPopScope') && swipesScreen.includes('onWillPop: () async => false'), 'Partner filter-change dialog should be non-dismissible with back disabled.');
assert(swipesScreen.includes('Update filters required'), 'Fallback blocked state should exist if the filter-change dialog is removed by platform.');
assert(coupleProvider.includes('clearHandledFilterChangeMarkers'), 'Provider handled filter-change markers should be clearable across boundaries.');
assert(swipeProvider.includes('clearDeckError'), 'Pair retry/loading should clear transient deck errors before retry.');

console.log('Pair round coordination assertions passed.');
