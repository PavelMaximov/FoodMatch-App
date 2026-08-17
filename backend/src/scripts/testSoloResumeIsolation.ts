import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(__dirname, '../../..');
const swipes = fs.readFileSync(path.join(root, 'food_match/lib/features/swipes/presentation/screens/swipes_screen.dart'), 'utf8');
const provider = fs.readFileSync(path.join(root, 'food_match/lib/features/couple/logic/couple_provider.dart'), 'utf8');
const invitations = fs.readFileSync(path.join(root, 'backend/src/modules/couples/services/coupleInvitationService.ts'), 'utf8');
const compactCard = fs.readFileSync(path.join(root, 'food_match/lib/shared/widgets/dish_compact_card.dart'), 'utf8');
const gridCard = fs.readFileSync(path.join(root, 'food_match/lib/shared/widgets/dish_grid_card.dart'), 'utf8');
const recipeDetail = fs.readFileSync(path.join(root, 'food_match/lib/features/dishes/presentation/screens/recipe_detail_screen.dart'), 'utf8');

assert(swipes.includes('beginSoloResumeIsolation()'), 'Solo Continue must isolate Pair continuation state.');
assert(swipes.includes('await swipeProvider.loadResumableSoloSession()'), 'Solo Continue must explicitly restore its backend session.');
assert(swipes.includes('prepare skipped reason=current_resume_mode_solo'), 'Pair deck acquisition must have a Solo-resume guard.');
assert(swipes.includes("error.code == 'PAIR_SESSION_INACTIVE'"), 'Inactive Pair sessions must stop canonical deck retries.');
assert(provider.includes('getInvitation(activeOutgoing.id)'), 'Sender status polling must be scoped to the active invite id.');
assert(provider.includes('ignored during solo resume'), 'Invitation actions must be suppressed during Solo resume.');
assert(invitations.includes("toUserId: objectId") && invitations.includes("status: 'pending'"), 'Pending query must return incoming pending invitations only.');
assert(!invitations.includes("status: { $in: ['pending', 'accepted'"), 'Pending query must not include outgoing history.');
assert(compactCard.includes('dish.totalTimeDisplay'), 'Compact cards must use normalized total time.');
assert(gridCard.includes('dish.totalTimeDisplay'), 'Grid cards must use normalized total time.');
assert(recipeDetail.includes('dish.totalTimeDisplay'), 'Recipe detail must use the same normalized total time.');

console.log('Solo resume isolation regression checks passed.');
