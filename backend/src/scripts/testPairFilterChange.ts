import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const model = readFileSync('src/modules/couples/models/CoupleSession.ts', 'utf8');
const service = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
const deckService = readFileSync('src/modules/couples/services/coupleDeckService.ts', 'utf8');
const routes = readFileSync('src/modules/couples/routes/coupleRoutes.ts', 'utf8');
const invitationService = readFileSync('src/modules/couples/services/coupleInvitationService.ts', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
const preSwipeScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/pre_swipe_filter_screen.dart', 'utf8');
const inlineCard = readFileSync('../food_match/lib/features/swipes/presentation/widgets/inline_deck_end_restart_card.dart', 'utf8');
const repository = readFileSync('../food_match/lib/data/repositories/couple_repository.dart', 'utf8');
const apiConstants = readFileSync('../food_match/lib/core/constants/api_constants.dart', 'utf8');
const pubspec = readFileSync('../food_match/pubspec.yaml', 'utf8');

assert(model.includes('partner_action_required'), 'Pair lifecycle should include committed partner_action_required state.');
assert(model.includes("reason: 'filter_change'"), 'Pair lifecycle should include filter_change reason.');
assert(routes.includes('/current/filter-change/commit'), 'Filter-change commit route should be registered.');
assert(service.includes('commitFilterChange'), 'CoupleService should commit filter-change after apply.');
const startBody = service.slice(service.indexOf('async markFilterChangeStarted'), service.indexOf('async commitFilterChange'));
assert(!startBody.includes('clearPreparedDeck(session)'), 'Starting local filter edit must not clear preparedDeck.');
assert(startBody.includes("status: 'local_editing'"), 'Starting filter edit should remain local/non-partner-visible.');
const commitBody = service.slice(service.indexOf('async commitFilterChange'), service.indexOf('async leaveSession'));
assert(commitBody.includes("status: 'partner_action_required'"), 'Commit should create partner-visible filter-change event.');
assert(commitBody.includes('clearPreparedDeck(session)'), 'Commit should invalidate preparedDeck after apply.');
assert(commitBody.includes('+ 1'), 'Each commit should increment generation/event id.');
assert(!commitBody.includes('CoupleInvitation'), 'Committing filter change must not create invitations.');
assert(deckService.includes('PAIR_WAITING_FOR_PARTNER_FILTERS'), 'Deck prepare should return PAIR_WAITING_FOR_PARTNER_FILTERS while partner has not confirmed.');
assert(invitationService.includes('createContinueAsBeforeInvite'), 'Continue-as-before should still create invitations.');
assert(apiConstants.includes('coupleFilterChangeCommit'), 'Flutter API constants should expose filter-change commit.');
assert(repository.includes('commitFilterChange'), 'CoupleRepository should call filter-change commit.');
assert(swipesScreen.includes('commitPairFilterChange: true'), 'Pair Filters apply should commit only when pre-filter completes.');
assert(!swipesScreen.includes('Partner is changing filters'), 'Partner edit-start notification copy should be removed.');
assert(!swipesScreen.includes("child: const Text('Wait')"), 'Filter-change dialog should not leave partner waiting on stale deck.');
assert(swipesScreen.includes('Partner changed filters'), 'Partner should see committed filter-change notification.');
assert(preSwipeScreen.includes('commitPairFilterChange'), 'Pre-swipe should support apply-time filter-change commit.');
assert(inlineCard.includes("assets/animations/waiting.json"), 'Inline deck-end waiting/loading should use waiting.json.');
assert(pubspec.includes('assets/animations/waiting.json'), 'waiting.json should be registered in pubspec.');

console.log('Pair filter-change assertions passed.');
