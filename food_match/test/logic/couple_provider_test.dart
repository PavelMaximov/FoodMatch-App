import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/couple.dart';
import 'package:food_match/data/models/couple_invitation.dart';
import 'package:food_match/data/models/couple_filter_state.dart';
import 'package:food_match/data/repositories/couple_repository.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/couple/logic/couple_provider.dart';

void main() {
  late CoupleProvider provider;
  late _FakeCoupleRepository fakeRepo;

  const Couple couple = Couple(
    id: 'c1',
    inviteCode: 'ABC123',
    members: <String>['u1', 'u2'],
    memberProfiles: <CoupleMemberProfile>[
      CoupleMemberProfile(id: 'u1'),
      CoupleMemberProfile(id: 'u2'),
    ],
  );

  setUp(() {
    fakeRepo = _FakeCoupleRepository()..currentCouple = couple;
    provider = CoupleProvider(repository: fakeRepo);
    provider.setAuthenticatedUser('u1', isAuthenticated: true);
  });

  tearDown(() => provider.dispose());

  test('create sets couple', () async {
    await provider.createCouple();

    expect(provider.currentCouple?.inviteCode, 'ABC123');
    expect(provider.error, isNull);
  });

  test('join sets couple', () async {
    await provider.joinCouple('ABC123');

    expect(provider.hasCouple, true);
  });

  test('leave clears couple', () async {
    provider.currentCouple = couple;

    await provider.leaveCouple();

    expect(provider.currentCouple, isNull);
    expect(fakeRepo.didLeave, isTrue);
  });

  test('loadCouple loads current couple', () async {
    await provider.loadCouple();

    expect(provider.currentCouple?.id, 'c1');
  });

  test('continuation survives polling into its newly created session', () async {
    await provider.loadCouple();
    final invitation = await provider.createContinueAsBeforeInvite();
    expect(invitation?.newCoupleSessionId, 'continued');

    // The server closes c1 and creates a one-member session for the invite.
    fakeRepo.currentCouple = const Couple(
      id: 'continued', inviteCode: 'NEW123', members: ['u1'],
      memberProfiles: [CoupleMemberProfile(id: 'u1')],
    );
    await provider.loadCouple(force: true);
    await provider.refreshInvitations();

    expect(provider.hasPartner, isFalse);
    expect(provider.outgoingContinuationInvite?.id, invitation?.id);
    expect(provider.hasPendingContinuation, isTrue);
    expect(provider.shouldAcquireDeckAfterContinuationInvite, isFalse);
  });

  test('unrelated session change clears the old continuation', () async {
    await provider.loadCouple();
    await provider.createContinueAsBeforeInvite();
    fakeRepo.currentCouple = const Couple(
      id: 'unrelated', inviteCode: 'OTHER1', members: ['u1'],
      memberProfiles: [CoupleMemberProfile(id: 'u1')],
    );
    await provider.loadCouple(force: true);
    expect(provider.outgoingContinuationInvite, isNull);
  });

  test('temporary status failure keeps waiting and acceptance still resumes', () async {
    await provider.createContinueAsBeforeInvite();
    fakeRepo.invitationError = TimeoutException('offline');
    await provider.refreshInvitations();
    expect(provider.outgoingContinuationInvite?.id, 'invite-1');

    fakeRepo.invitationError = null;
    fakeRepo.invitationStatus = 'accepted';
    await provider.refreshInvitations();
    expect(provider.outgoingContinuationInvite, isNull);
    expect(provider.shouldAcquireDeckAfterContinuationInvite, isTrue);
    expect(provider.consumeContinuationDeckAcquisition(),
        PairContinuationFlowOrigin.previousSessionInviteSender);
    await provider.refreshInvitations();
    expect(provider.shouldAcquireDeckAfterContinuationInvite, isFalse);
  });

  test('missing invitation returns to resume instead of pair creation', () async {
    await provider.createContinueAsBeforeInvite();
    fakeRepo.invitationError = const ApiException('gone', statusCode: 404);
    await provider.refreshInvitations();
    expect(provider.outgoingContinuationInvite, isNull);
    expect(provider.shouldReturnToResumeAfterContinuationDeclined, isTrue);
  });

}

class _FakeCoupleRepository extends CoupleRepository {
  _FakeCoupleRepository() : super(ApiService());

  Couple? currentCouple;
  bool didLeave = false;
  Object? invitationError;
  String invitationStatus = 'pending';

  CoupleInvitation get invitation => CoupleInvitation.fromJson({
    'id': 'invite-1',
    'fromUserId': 'u1',
    'toUserId': 'u2',
    'direction': 'outgoing',
    'status': invitationStatus,
    'newCoupleSessionId': 'continued',
    'sessionActive': true,
  });

  @override
  Future<CoupleInvitation> continueAsBefore() async => invitation;

  @override
  Future<List<CoupleInvitation>> getPendingInvitations() async => [];

  @override
  Future<CoupleInvitation> getInvitation(String id) async {
    if (invitationError != null) throw invitationError!;
    return invitation;
  }

  static const CoupleFilterState _filterState = CoupleFilterState(
    myChoices: CoupleFilterChoices(),
    bothConfirmed: false,
    compatibility: 0,
    status: 'draft',
  );

  @override
  Future<Couple> create() async => currentCouple!;

  @override
  Future<Couple> join(
    String inviteCode, {
    bool replaceEmptyCurrentSession = false,
  }) async =>
      currentCouple!;

  @override
  Future<Couple?> getMyCouple() async => currentCouple;

  @override
  Future<void> leave() async {
    didLeave = true;
  }

  @override
  Future<CoupleFilterState> getFilterState() async => _filterState;
}
