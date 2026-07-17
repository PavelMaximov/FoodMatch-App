import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const model = readFileSync('src/modules/couples/models/CoupleSession.ts', 'utf8');
const coupleService = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
const deckService = readFileSync('src/modules/couples/services/coupleDeckService.ts', 'utf8');
const invitationService = readFileSync('src/modules/couples/services/coupleInvitationService.ts', 'utf8');
const routes = readFileSync('src/modules/couples/routes/coupleRoutes.ts', 'utf8');
const authProvider = readFileSync('../food_match/lib/features/auth/logic/auth_provider.dart', 'utf8');
const coupleProvider = readFileSync('../food_match/lib/features/couple/logic/couple_provider.dart', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
const preSwipeScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/pre_swipe_filter_screen.dart', 'utf8');
const cacheService = readFileSync('../food_match/lib/data/local/cache_service.dart', 'utf8');

assert(model.includes('pairLifecycleState'), 'CoupleSession should persist pairLifecycleState.');
assert(model.includes("'needs_resync'"), 'Pair lifecycle should support needs_resync.');
assert(routes.includes('/current/partner-disconnect'), 'Partner disconnect endpoint should be registered.');
assert(coupleService.includes('markPartnerDisconnected'), 'CoupleService should mark partner disconnect.');
assert(coupleService.includes("reason: 'partner_logged_out'"), 'Disconnect should store partner_logged_out reason.');
assert(coupleService.includes('clearPreparedDeck(session)'), 'Disconnect should invalidate prepared deck.');
assert(coupleService.includes("filterState = { users: [], status: 'draft'"), 'Disconnect should reset filter confirmations.');
const disconnectBody = coupleService.slice(coupleService.indexOf('async markPartnerDisconnected'), coupleService.indexOf('async leaveSession'));
assert(!disconnectBody.includes('MatchModel.deleteMany'), 'Disconnect flow must not delete matches.');
assert(deckService.includes('PAIR_SESSION_NEEDS_RESYNC'), 'Deck prepare should reject needs_resync sessions.');
assert(!coupleService.includes("session.pairLifecycleState = { status: 'active'"), 'Filter updates must not reset lifecycle to active.');
assert(invitationService.includes("session.pairLifecycleState = { status: 'active'"), 'Continuation accept should reset lifecycle to active.');
assert(invitationService.includes('clearPreparedDeck(session)'), 'Continuation accept should clear stale prepared decks.');
assert(authProvider.includes('couplePartnerDisconnect'), 'Logout should call pair disconnect before token clear.');
assert(authProvider.includes('[PairLifecycle] logout -> partner-disconnect requested'), 'Logout should log partner-disconnect request.');
const logoutBody = authProvider.slice(authProvider.indexOf('Future<void> logout'), authProvider.indexOf('void _markAuthBoundaryChanged'));
assert(logoutBody.indexOf('_notifyPairDisconnectBeforeLogout') < logoutBody.indexOf('_clearAuthState'), 'Pair disconnect should be called before auth state is cleared.');
assert(coupleProvider.includes('needsPairResync'), 'Frontend should expose pair resync signal.');
assert(swipesScreen.includes('Partner left the session'), 'Partner disconnect dialog title should exist.');
assert(swipesScreen.includes('SessionResumeChoiceScreen'), 'Pair resync should land on SessionResumeChoiceScreen.');
assert(swipesScreen.includes('_pairLifecyclePollingTimer'), 'Swipes screen should poll pair lifecycle independently.');
assert(swipesScreen.includes('_startPairLifecyclePolling'), 'Pair lifecycle polling should start during pair flows.');
assert(swipesScreen.includes('_sendPairContinuationInvite'), 'Pair continue should send an invitation instead of opening filters directly.');
assert(swipesScreen.includes('[PairLifecycle] poll -> needs_resync detected'), 'Pair lifecycle polling should log needs_resync detection.');
assert(swipesScreen.includes('enum _PreSwipeFlowOrigin'), '_runPreSwipeFlow should require an explicit origin.');
assert(swipesScreen.includes('required _PreSwipeFlowOrigin origin'), '_runPreSwipeFlow should not allow a default/null origin.');
assert(swipesScreen.includes('[AppFlow] authBoundary -> blocked previous choice auto-open'), 'Auth-boundary startup should block previous-choice auto-open.');
assert(swipesScreen.includes('authBoundaryVersion != versionAtSchedule'), 'Post-frame previous-choice callbacks should be auth-boundary version guarded.');
assert(coupleProvider.includes('previousChoiceAfterInviteWasUserAccepted'), 'Manual invitation accept should remain distinguishable from stale auto-restore.');
assert(swipesScreen.includes('[AppFlow] startup resolved -> SessionResumeChoiceScreen'), 'Startup newOld should render SessionResumeChoiceScreen.');
assert(swipesScreen.includes('[AppFlow] startup resolved -> ModeSelection'), 'Startup modeSelection should render Mode Selection.');
assert(swipesScreen.includes('_loadCanonicalPairDeckAndShowSwipe'), 'Pair deck ready should load the canonical backend deck.');
assert(swipesScreen.includes('_clearStalePairDeckSetupState'), 'Pair deck ready should clear stale setup/session-resume state.');
assert(swipesScreen.includes('both_confirmed_waiting_poll'), 'Waiting user should transition to swipe after both users confirm filters.');
assert(!swipesScreen.includes('_pairContinuationFlowActive'), 'Canonical pair deck loading must not be scoped only to continuation flow.');
assert(swipesScreen.includes('_pairDeckReadyAutoLoadEnabled || _sessionResumeChoiceType == null'), 'Canonical pair deck loading should apply to non-continuation pair flows too.');
assert(swipesScreen.includes('provider.deck.isNotEmpty &&'), 'Deck end should only render for an actually loaded deck.');
assert(swipesScreen.includes('[AppFlow] pair deck ready -> Swipe'), 'Pair deck ready should route/correct to Swipe.');
assert(swipesScreen.includes('[DeckEnd] render check'), 'Deck-end render guard should log its decision.');
assert(coupleProvider.includes('[PairFlow] both filters confirmed'), 'Both-confirmed filter state should be logged.');
assert(preSwipeScreen.includes('PAIR_SESSION_NEEDS_RESYNC'), 'Frontend should handle pair deck resync error.');
assert(preSwipeScreen.includes('deckPrepare blocked -> PAIR_SESSION_NEEDS_RESYNC'), 'Frontend should log blocked pair deck prepare.');
assert(cacheService.includes('previous_filter_choice'), 'Auth-boundary cache cleanup should remove previous filter choice route keys.');
assert(cacheService.includes('pendingPreviousChoice'), 'Auth-boundary cache cleanup should remove pending previous-choice keys.');

console.log('Pair session resync assertions passed.');
