import { readFileSync } from 'fs';

function assert(condition: boolean, message: string) {
  if (!condition) {
    throw new Error(message);
  }
}

const service = readFileSync('src/modules/couples/services/coupleService.ts', 'utf8');
const controller = readFileSync('src/modules/couples/controllers/coupleController.ts', 'utf8');
const schema = readFileSync('src/modules/couples/dto/coupleSchemas.ts', 'utf8');
const provider = readFileSync('../food_match/lib/features/couple/logic/couple_provider.dart', 'utf8');
const repository = readFileSync('../food_match/lib/data/repositories/couple_repository.dart', 'utf8');
const pairScreen = readFileSync('../food_match/lib/features/swipes/presentation/screens/pair_connection_step_screen.dart', 'utf8');

assert(schema.includes('replaceEmptyCurrentSession'), 'Join schema should accept replaceEmptyCurrentSession.');
assert(controller.includes('replaceEmptyCurrentSession: req.body.replaceEmptyCurrentSession === true'), 'Controller should pass replaceEmptyCurrentSession to the service.');
assert(service.includes('const targetSession = await CoupleSessionModel.findOne({ inviteCode: normalizedInviteCode })'), 'Target invite should be loaded before current session replacement.');
assert(service.includes("'INVALID_INVITE_CODE'"), 'Invalid invite code should use stable INVALID_INVITE_CODE.');
assert(service.includes("'SESSION_FULL'"), 'Full target sessions should use stable SESSION_FULL.');
assert(service.includes("'SESSION_INACTIVE'"), 'Inactive target sessions should use stable SESSION_INACTIVE.');
assert(service.includes("'ALREADY_IN_TARGET_SESSION'"), 'Already-in-target sessions should use stable ALREADY_IN_TARGET_SESSION.');
assert(service.includes("'CANNOT_JOIN_OWN_SESSION'"), 'Own-code joins should use stable CANNOT_JOIN_OWN_SESSION.');
assert(service.includes("'ACTIVE_SESSION_HAS_PARTNER'"), 'Unsafe replacement should use stable ACTIVE_SESSION_HAS_PARTNER.');
assert(service.includes("'ACTIVE_SOLO_SESSION_EXISTS'"), 'Active solo conflicts should use stable ACTIVE_SOLO_SESSION_EXISTS.');
assert(service.includes("active.status = 'closed'"), 'Empty current pair session should be closed before replacement join.');
assert(service.indexOf('if (!targetSession)') < service.indexOf("active.status = 'closed'"), 'Target validation must happen before closing current session.');
assert(service.includes('currentUserIsOnlyMember'), 'Replacement should be limited to a current session where the user is the only member.');
assert(repository.includes("if (replaceEmptyCurrentSession) 'replaceEmptyCurrentSession': true"), 'Repository should send replaceEmptyCurrentSession when requested.');
assert(pairScreen.includes('replaceEmptyCurrentSession: true'), 'Pair connection flow should request safe empty-session replacement.');
assert(provider.includes('ACTIVE_SESSION_HAS_PARTNER'), 'Provider should map ACTIVE_SESSION_HAS_PARTNER to user-friendly copy.');
assert(provider.includes('CANNOT_JOIN_OWN_SESSION'), 'Provider should map CANNOT_JOIN_OWN_SESSION to user-friendly copy.');
assert(pairScreen.includes('provider.error != null'), 'Pair connection screen should avoid success cleanup when join fails.');

console.log('Pair join replacement static assertions passed.');
