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

  test('invitation polls share one request and ignore previous account results', () async {
    final pending = Completer<List<CoupleInvitation>>();
    fakeRepo.pendingResponse = pending.future;
    final first = provider.refreshInvitations();
    final second = provider.refreshInvitations();
    expect(fakeRepo.pendingLoads, 1);
    provider.setAuthenticatedUser('u3', isAuthenticated: true);
    pending.complete([fakeRepo.invitation]);
    await Future.wait([first, second]);
    expect(provider.pendingInvitations, isEmpty);
  });

  test('new account can refresh before the old poll completes', () async {
    final pending = Completer<List<CoupleInvitation>>();
    fakeRepo.pendingResponse = pending.future;
    final old = provider.refreshInvitations();
    provider.setAuthenticatedUser('u3', isAuthenticated: true);
    fakeRepo.pendingResponse = null;
    await provider.refreshInvitations();
    expect(fakeRepo.pendingLoads, 2);
    pending.complete([fakeRepo.invitation]);
    await old;
    expect(provider.pendingInvitations, isEmpty);
  });

  test('late accepted outgoing status cannot resume after logout', () async {
    provider.outgoingContinuationInvite = fakeRepo.invitation;
    final status = Completer<CoupleInvitation>();
    fakeRepo.statusResponse = status.future;
    final refresh = provider.refreshInvitations();
    await Future<void>.delayed(Duration.zero);
    provider.setAuthenticatedUser(null, isAuthenticated: false);
    fakeRepo.invitationStatus = 'accepted';
    status.complete(fakeRepo.invitation);
    await refresh;
    expect(provider.outgoingContinuationInvite, isNull);
    expect(provider.currentCouple, isNull);
    expect(provider.shouldAcquireDeckAfterContinuationInvite, isFalse);
  });

  test('late continuation creation cannot attach to the next account', () async {
    final response = Completer<CoupleInvitation>();
    fakeRepo.continueResponse = response.future;
    final create = provider.createContinueAsBeforeInvite();
    provider.setAuthenticatedUser('u3', isAuthenticated: true);
    response.complete(fakeRepo.invitation);
    expect(await create, isNull);
    expect(provider.outgoingContinuationInvite, isNull);
  });

  test('late accept cannot restore a session after account switch', () async {
    final response = Completer<Couple?>();
    fakeRepo.acceptResponse = response.future;
    final accept = provider.acceptInvitation(fakeRepo.invitation);
    provider.setAuthenticatedUser('u3', isAuthenticated: true);
    response.complete(couple);
    await accept;
    expect(provider.currentCouple, isNull);
    expect(provider.shouldAcquireDeckAfterContinuationInvite, isFalse);
  });

  test('accepting for the current account still acquires the shared deck', () async {
    await provider.acceptInvitation(fakeRepo.invitation);
    expect(provider.currentCouple?.id, 'c1');
    expect(provider.shouldAcquireDeckAfterContinuationInvite, isTrue);
    expect(provider.consumeContinuationDeckAcquisition(),
        PairContinuationFlowOrigin.previousSessionInviteAccepter);
  });

  test('late decline cannot hide invitations in the next account', () async {
    final response = Completer<void>();
    fakeRepo.declineResponse = response.future;
    final decline = provider.declineInvitation(fakeRepo.invitation);
    provider.setAuthenticatedUser('u3', isAuthenticated: true);
    response.complete();
    await decline;
    expect(provider.hiddenInvitationIds, isEmpty);
  });

  test('partner departure is handled once per session and generation', () async {
    Couple disconnected(String id, int generation) => Couple.fromJson({
      'id': id,
      'inviteCode': 'ABC123',
      'members': ['u1', 'u2'],
      'pairLifecycleState': {
        'status': 'needs_resync', 'changedBy': 'u2', 'generation': generation,
      },
    });
    fakeRepo.currentCouple = disconnected('first', 1);
    await provider.loadCouple(force: true);
    expect(provider.consumeOpenSessionResumeForResync(), isTrue);
    expect(provider.isWaitingForPartnerReturn, isTrue);
    await provider.loadCouple(force: true);
    expect(provider.consumeOpenSessionResumeForResync(), isFalse);
    fakeRepo.currentCouple = disconnected('second', 1);
    await provider.loadCouple(force: true);
    expect(provider.consumeOpenSessionResumeForResync(), isTrue);
    fakeRepo.currentCouple = disconnected('second', 2);
    await provider.loadCouple(force: true);
    expect(provider.consumeOpenSessionResumeForResync(), isTrue);
  });

  test('returning user is offered continuation rather than waiting for themselves', () async {
    fakeRepo.currentCouple = Couple.fromJson({
      'id': 'pair', 'inviteCode': 'ABC123', 'members': ['u1', 'u2'],
      'pairLifecycleState': {'status': 'needs_resync', 'changedBy': 'u1', 'generation': 1},
    });
    await provider.loadCouple(force: true);
    expect(provider.isWaitingForPartnerReturn, isFalse);
    expect(provider.needsPairResync, isFalse);
  });

  test('a refreshed pending delivery is visible after the old one was dismissed', () async {
    CoupleInvitation incoming(String session, String updated) => CoupleInvitation.fromJson({
      'id': 'same-pending-row', 'fromUserId': 'u2', 'toUserId': 'u1',
      'direction': 'incoming', 'status': 'pending',
      'newCoupleSessionId': session, 'updatedAt': updated,
    });
    final old = incoming('first', '2026-11-04T10:00:00Z');
    provider.pendingInvitations = [old];
    provider.hideInvitationLocally(old);
    expect(provider.nextIncomingInvitation, isNull);
    final next = incoming('second', '2026-11-04T10:01:00Z');
    provider.pendingInvitations = [next];
    expect(provider.nextIncomingInvitation?.deliveryKey, next.deliveryKey);
    expect(next.deliveryKey, isNot(old.deliveryKey));
    final refreshed = incoming('first', '2026-11-04T10:02:00Z');
    provider.pendingInvitations = [refreshed];
    expect(provider.nextIncomingInvitation?.deliveryKey, refreshed.deliveryKey);
  });

  test('old filter 404 cannot discard a successful continuation invitation', () async {
    await provider.loadCouple();
    final filters = Completer<CoupleFilterState>();
    fakeRepo.filterResponse = filters.future;
    final oldRead = provider.refreshFilterState();
    final invitation = Completer<CoupleInvitation>();
    fakeRepo.continueResponse = invitation.future;
    final continuation = provider.createContinueAsBeforeInvite();
    filters.completeError(const ApiException('Old session closed', statusCode: 404, code: 'PAIR_SESSION_INACTIVE'));
    await oldRead;
    expect(provider.sessionEndedMessage, isNull);
    invitation.complete(fakeRepo.invitation);
    final result = await continuation;
    expect(result?.id, 'invite-1');
    expect(provider.outgoingContinuationInvite?.id, 'invite-1');
    expect(provider.sessionEndedMessage, isNull);
  });

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

  test('leave during background refresh does not restore the old session', () async {
    provider.currentCouple = couple;
    final response = Completer<Couple?>();
    fakeRepo.coupleResponse = response.future;
    final refresh = provider.loadCouple(force: true);
    expect(provider.isLoading, isTrue);

    await provider.leaveCouple();
    expect(fakeRepo.didLeave, isTrue);
    expect(provider.hasCouple, isFalse);

    response.complete(couple);
    await refresh;
    expect(provider.hasCouple, isFalse);
    expect(provider.error, isNull);
  });

  test('failed leave keeps the session available for retry', () async {
    provider.currentCouple = couple;
    fakeRepo.leaveError = const ApiException('offline', statusCode: 503);
    await provider.leaveCouple();
    expect(provider.hasCouple, isTrue);
    expect(provider.error, isNotNull);

    fakeRepo.leaveError = null;
    await provider.leaveCouple();
    expect(provider.hasCouple, isFalse);
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
  Future<Couple?>? coupleResponse;
  Future<CoupleFilterState>? filterResponse;
  Object? leaveError;
  Object? invitationError;
  String invitationStatus = 'pending';
  Future<List<CoupleInvitation>>? pendingResponse;
  Future<CoupleInvitation>? statusResponse;
  Future<CoupleInvitation>? continueResponse;
  Future<Couple?>? acceptResponse;
  Future<void>? declineResponse;
  int pendingLoads = 0;

  @override
  Future<Couple?> acceptInvitation(String id) async =>
      acceptResponse == null ? currentCouple : await acceptResponse!;

  @override
  Future<void> declineInvitation(String id) async {
    if (declineResponse != null) await declineResponse!;
  }

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
  Future<CoupleInvitation> continueAsBefore() async =>
      continueResponse == null ? invitation : await continueResponse!;

  @override
  Future<List<CoupleInvitation>> getPendingInvitations() async {
    pendingLoads++;
    return pendingResponse == null ? [] : await pendingResponse!;
  }

  @override
  Future<CoupleInvitation> getInvitation(String id) async {
    if (invitationError != null) throw invitationError!;
    return statusResponse == null ? invitation : await statusResponse!;
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
  Future<Couple?> getMyCouple() async => coupleResponse != null
      ? await coupleResponse!
      : currentCouple;

  @override
  Future<void> leave({String? sessionId}) async {
    didLeave = true;
    if (leaveError != null) throw leaveError!;
  }

  @override
  Future<CoupleFilterState> getFilterState() async =>
      filterResponse == null ? _filterState : await filterResponse!;
}
