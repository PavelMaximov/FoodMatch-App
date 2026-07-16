import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const model = readFileSync('src/modules/couples/models/CoupleSession.ts', 'utf8');
const coupleService = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
const deckService = readFileSync('src/modules/couples/services/coupleDeckService.ts', 'utf8');
const routes = readFileSync('src/modules/couples/routes/coupleRoutes.ts', 'utf8');
const authProvider = readFileSync('../food_match/lib/features/auth/logic/auth_provider.dart', 'utf8');
const coupleProvider = readFileSync('../food_match/lib/features/couple/logic/couple_provider.dart', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
const preSwipeScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/pre_swipe_filter_screen.dart', 'utf8');

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
assert(authProvider.includes('couplePartnerDisconnect'), 'Logout should call pair disconnect before token clear.');
const logoutBody = authProvider.slice(authProvider.indexOf('Future<void> logout'), authProvider.indexOf('void _markAuthBoundaryChanged'));
assert(logoutBody.indexOf('_notifyPairDisconnectBeforeLogout') < logoutBody.indexOf('_clearAuthState'), 'Pair disconnect should be called before auth state is cleared.');
assert(coupleProvider.includes('needsPairResync'), 'Frontend should expose pair resync signal.');
assert(swipesScreen.includes('Partner left the session'), 'Partner disconnect dialog title should exist.');
assert(swipesScreen.includes('SessionResumeChoiceScreen'), 'Pair resync should land on SessionResumeChoiceScreen.');
assert(preSwipeScreen.includes('PAIR_SESSION_NEEDS_RESYNC'), 'Frontend should handle pair deck resync error.');

console.log('Pair session resync assertions passed.');
