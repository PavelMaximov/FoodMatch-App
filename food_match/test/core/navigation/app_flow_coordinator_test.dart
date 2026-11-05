import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/navigation/app_flow_coordinator.dart';
import 'package:food_match/data/repositories/swipe_repository.dart';
import 'package:food_match/data/services/api_service.dart';

class _Repository extends SwipeRepository {
  _Repository(this.response) : super(ApiService());
  final dynamic response;
  @override
  Future<dynamic> getSessionResumeState() async => response;
  @override
  Future<dynamic> getLastFilterPreset(String mode) async =>
      throw StateError('Presets must not determine session availability');
}

void main() {
  const coordinator = AppFlowCoordinator();
  Future<StartupRouteDecision> resolve(String mode, String status, String action) =>
      coordinator.resolveStartupRoute(swipeRepository: _Repository({
        'session': {'id': 'session', 'mode': mode, 'status': status, 'action': action},
      }));
  test('closed last pair leads to mode choice and never fictional Solo resume', () async {
    final decision = await resolve('paired', 'closed', 'new');
    expect(decision.route, StartupRoute.modeSelection);
    expect(decision.previousMode, AppFlowMode.paired);
    expect(decision.notice, contains('shared session has ended'));
  });
  test('active and completed Solo sessions can resume', () async {
    for (final status in ['active', 'completed']) {
      final decision = await resolve('solo', status, 'resume');
      expect(decision.route, StartupRoute.sessionResumeChoice);
      expect(decision.previousMode, AppFlowMode.solo);
    }
  });
  test('waiting pair setup does not pretend to be a completed session', () async {
    final decision = await resolve('paired', 'active', 'connect_pair');
    expect(decision.route, StartupRoute.pairConnection);
  });
  test('active pair continues as Pair', () async {
    final decision = await resolve('paired', 'active', 'resume');
    expect(decision.previousMode, AppFlowMode.paired);
    expect(decision.route, StartupRoute.sessionResumeChoice);
  });
  test('invalid response is retriable rather than guessing Solo', () async {
    await expectLater(coordinator.resolveStartupRoute(swipeRepository: _Repository({})),
        throwsFormatException);
  });
}
