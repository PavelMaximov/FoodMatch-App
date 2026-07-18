import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const model = readFileSync('src/modules/couples/models/CoupleSession.ts', 'utf8');
const service = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
const routes = readFileSync('src/modules/couples/routes/coupleRoutes.ts', 'utf8');
const invitationService = readFileSync('src/modules/couples/services/coupleInvitationService.ts', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
const inlineCard = readFileSync('../food_match/lib/features/swipes/presentation/widgets/inline_deck_end_restart_card.dart', 'utf8');
const repository = readFileSync('../food_match/lib/data/repositories/couple_repository.dart', 'utf8');
const apiConstants = readFileSync('../food_match/lib/core/constants/api_constants.dart', 'utf8');
const pubspec = readFileSync('../food_match/pubspec.yaml', 'utf8');

assert(model.includes('filter_change_pending'), 'Pair lifecycle should include filter_change_pending.');
assert(model.includes("reason: 'filter_change'"), 'Pair lifecycle should include filter_change reason.');
assert(routes.includes('/current/filter-change/start'), 'Filter-change start route should be registered.');
assert(service.includes('markFilterChangeStarted'), 'CoupleService should mark filter-change start.');
const filterChangeBody = service.slice(service.indexOf('async markFilterChangeStarted'), service.indexOf('async leaveSession'));
assert(!filterChangeBody.includes('clearPreparedDeck(session)'), 'Starting filter change must not clear preparedDeck.');
assert(!filterChangeBody.includes('CoupleInvitation'), 'Starting filter change must not create invitations.');
assert(invitationService.includes('createContinueAsBeforeInvite'), 'Continue-as-before should still create invitations.');
assert(apiConstants.includes('coupleFilterChangeStart'), 'Flutter API constants should expose filter-change start.');
assert(repository.includes('startFilterChange'), 'CoupleRepository should call filter-change start.');
assert(swipesScreen.includes('startPairFilterChange'), 'Pair Filters should start filter-change state.');
assert(!swipesScreen.includes('await _sendPairContinuationInvite(coupleProvider);\n  }\n\n  Future<void> _showPartnerChangingFiltersDialog'), 'Pair filter-change flow should not send continuation invitation.');
assert(swipesScreen.includes('Partner is changing filters'), 'Partner should see filter-change notification.');
assert(inlineCard.includes("assets/animations/waiting.json"), 'Inline deck-end waiting/loading should use waiting.json.');
assert(pubspec.includes('assets/animations/waiting.json'), 'waiting.json should be registered in pubspec.');

console.log('Pair filter-change assertions passed.');
