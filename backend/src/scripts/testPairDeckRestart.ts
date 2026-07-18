import { readFileSync } from 'fs';

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

const model = readFileSync('src/modules/couples/models/CoupleSession.ts', 'utf8');
const service = readFileSync('src/modules/couples/services/coupleDeckService.ts', 'utf8');
const routes = readFileSync('src/modules/couples/routes/coupleRoutes.ts', 'utf8');
const controller = readFileSync('src/modules/couples/controllers/coupleController.ts', 'utf8');
const coupleService = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');

assert(model.includes('restartState'), 'CoupleSession should persist restartState.');
assert(model.includes("status: 'idle' | 'waiting' | 'ready'"), 'Restart state should expose idle/waiting/ready statuses.');
assert(routes.includes("/deck/restart-request"), 'Restart request endpoint should be registered.');
assert(routes.includes("/deck/restart-status"), 'Restart status endpoint should be registered.');
assert(controller.includes('requestDeckRestart'), 'Controller should expose restart request handler.');
assert(controller.includes('getDeckRestartStatus'), 'Controller should expose restart status handler.');
assert(service.includes('requestDeckRestart'), 'Deck service should record restart requests.');
assert(service.includes('getDeckRestartStatus'), 'Deck service should return restart status.');
assert(service.includes('allRequested'), 'Restart response should report allRequested.');
assert(service.includes('PAIR_FILTER_CHANGE_IN_PROGRESS'), 'Restart request should be blocked while partner filter change is in progress.');
assert(service.includes('clearPreparedDeck(session)'), 'Prepared deck should be cleared when restart is ready.');
assert(service.includes("session.filterState = { users: [], status: 'draft'"), 'Filter confirmations should reset when both users restart.');
assert(!service.includes('MatchModel.deleteMany'), 'Pair deck restart must not delete previous matches.');
assert(coupleService.includes("session.restartState = { requestedBy: [], status: 'idle'"), 'Restart state should reset when users begin new filters.');
assert(swipesScreen.includes('_startPairRestartPolling'), 'Frontend should poll pair restart status while waiting.');
assert(swipesScreen.includes('InlineDeckEndRestartCard'), 'Frontend should render inline restart card at deck end.');

console.log('Pair deck restart assertions passed.');
