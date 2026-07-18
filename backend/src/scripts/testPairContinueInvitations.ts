import { readFileSync } from 'fs';

const model = readFileSync('src/modules/couples/models/CoupleInvitation.ts', 'utf8');
const service = readFileSync('src/modules/couples/services/coupleInvitationService.ts', 'utf8');
const routes = readFileSync('src/modules/couples/routes/coupleRoutes.ts', 'utf8');
const controller = readFileSync('src/modules/couples/controllers/coupleController.ts', 'utf8');
const lastFilterService = readFileSync('src/modules/filters/services/lastFilterPresetService.ts', 'utf8');
const coupleProvider = readFileSync('../food_match/lib/features/couple/logic/couple_provider.dart', 'utf8');
const swipesScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/swipes_screen.dart', 'utf8');
const resumeScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/session_resume_choice_screen.dart', 'utf8');

function assert(condition: unknown, message: string) {
  if (!condition) throw new Error(message);
}

assert(model.includes("'pending' | 'accepted' | 'declined' | 'expired' | 'cancelled'"), 'Invite model must include lifecycle statuses.');
assert(model.includes('fromUserId') && model.includes('toUserId') && model.includes('pairKey'), 'Invite model must include sender, recipient, and pairKey.');
assert(model.includes('matchedLastTime'), 'Invite model must include matchedLastTime for legacy metadata.');
assert(model.includes('mutualMatchCount'), 'Invite model must include mutualMatchCount.');
assert(routes.includes("/continue-as-before"), 'Continue-as-before route must exist.');
assert(routes.includes("/invitations/pending"), 'Pending invitations route must exist.');
assert(routes.includes("/invitations/:id/accept"), 'Accept route must exist.');
assert(routes.includes("/invitations/:id/decline"), 'Decline route must exist.');
assert(controller.includes('createContinueAsBeforeInvite'), 'Controller must create continue-as-before invite.');
assert(service.includes("pairKey: { $type: 'string', $ne: null }"), 'Continue invite should read last user-scoped paired preset without requiring active session.');
assert(service.includes('PREVIOUS_PARTNER_NOT_FOUND'), 'Missing previous partner should use a stable error code.');
assert(service.includes('pairKey.split'), 'Continue invite should resolve previous partner from pairKey.');
assert(service.includes('findOneAndUpdate') && service.includes('status: \'pending\''), 'Duplicate pending invite should be upserted, not duplicated.');
assert(service.includes('requireInviteForTarget') && service.includes('toUserId: new Types.ObjectId(userId)'), 'Only recipient can accept/decline invite.');
assert(service.includes("invite.status = 'accepted'"), 'Accept must mark invite accepted.');
assert(service.includes("invite.status = 'declined'"), 'Decline must mark invite declined.');
assert(service.includes("invite.status = 'expired'"), 'Expired invite cannot be accepted.');
assert(service.includes('getMyActiveSession(userId)'), 'Accept should return/activate current pair session.');
assert(service.includes('MatchModel.countDocuments'), 'mutualMatchCount must count MatchModel records.');
assert(service.includes('mutualMatchCount') && !service.includes('mutualMatchCount: lastPreset?.matchedLastTime'), 'mutualMatchCount must not use matchedLastTime/prepared count.');
assert(lastFilterService.includes('userId: new Types.ObjectId(userId), pairKey: buildPairKey'), 'Paired presets must remain user-scoped by pairKey.');
assert(!service.includes('userId: null'), 'Invitation flow must not use legacy userId:null paired presets.');
assert(coupleProvider.includes('outgoingContinuationInvite?.isPending == true'), 'Client should reuse an in-flight local continuation request.');
assert(coupleProvider.includes('hiddenInvitationIds.remove(acceptedInvite.id)'), 'Accepted continuation should clear a locally dismissed invite marker.');
assert(coupleProvider.includes('accepted continuation converging to previous choices'), 'Accepted continuation should reopen the required previous-choice flow.');
assert(swipesScreen.includes("child: const Text('Refresh')"), 'Continuation waiting state should provide Refresh recovery.');
assert(swipesScreen.includes("child: const Text('Start new session')"), 'Continuation waiting state should provide Start new session recovery.');
assert(resumeScreen.includes('_isContinuing'), 'Continue as before should disable repeated local taps while in flight.');

console.log('[PairContinueInvitations] static assertions passed');
