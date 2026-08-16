import { readFileSync } from 'fs';

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

const soloService = readFileSync('src/modules/solo-swipes/services/soloSwipeService.ts', 'utf8');
const soloRoutes = readFileSync('src/modules/solo-swipes/routes/soloSwipeRoutes.ts', 'utf8');
const coupleService = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
const swipeProvider = readFileSync('../food_match/lib/features/swipes/logic/swipe_provider.dart', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');

assert(soloRoutes.includes("router.post('/active/abandon'"), 'Solo abandon endpoint must remain available.');
assert(soloService.includes("session.status='abandoned'"), 'Active Solo must be marked abandoned.');
assert(soloService.includes('ok:true, abandoned:false'), 'Solo abandon must be idempotent when no session exists.');
assert(coupleService.includes("status: 'active'"), 'Pair guards must query only active Solo sessions.');
assert(swipeProvider.includes('Always call the idempotent backend endpoint'), 'Frontend must call abandon even when local Solo state is absent.');
assert(swipesScreen.includes("message: 'Starting a new session...'"), 'Start new must use the pending overlay.');
assert(swipesScreen.includes('Could not start a new session.'), 'Start new must expose a recoverable error.');

console.log('Solo abandon/start-new static assertions passed.');
