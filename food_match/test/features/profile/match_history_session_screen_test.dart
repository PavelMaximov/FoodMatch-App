import 'dart:async';
import 'package:food_match/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:food_match/data/models/match_history.dart';
import 'package:food_match/data/repositories/match_history_repository.dart';
import 'package:food_match/features/profile/presentation/screens/profile_detail_screens.dart';

class _Repository implements MatchHistoryRepository {
  final requests = <String, Completer<MatchHistorySession?>>{};
  @override
  Future<MatchHistorySession?> getSession(String id) {
    final request = Completer<MatchHistorySession?>();
    requests[id] = request;
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MatchHistorySession _session(String id, MatchHistoryMode mode) =>
    MatchHistorySession(
      sessionId: id,
      mode: mode,
      startedAt: DateTime(2026),
      completedAt: null,
      partnerName: null,
      dishCount: 0,
      previewDishes: const [],
      dishes: const [],
    );
Widget _app(
  _Repository repository,
  String id, {
  MatchHistorySession? initial,
}) => Provider<MatchHistoryRepository>.value(
  value: repository,
  child: MaterialApp(
    theme: AppTheme.light,
    home: MatchHistorySessionScreen(sessionId: id, initialSession: initial),
  ),
);
void main() {
  testWidgets('stale session detail cannot overwrite a newer session', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_app(repository, 'a'));
    await tester.pumpWidget(_app(repository, 'b'));
    repository.requests['b']!.complete(_session('b', MatchHistoryMode.pair));
    await tester.pumpAndSettle();
    expect(find.text('Pair Session'), findsOneWidget);
    repository.requests['a']!.complete(_session('a', MatchHistoryMode.solo));
    await tester.pumpAndSettle();
    expect(find.text('Pair Session'), findsOneWidget);
    expect(find.text('Solo Session'), findsNothing);
  });
  testWidgets('navigation preview still fetches full detail', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      _app(repository, 'a', initial: _session('a', MatchHistoryMode.solo)),
    );
    expect(repository.requests.keys, ['a']);
    repository.requests['a']!.complete(_session('a', MatchHistoryMode.pair));
    await tester.pumpAndSettle();
    expect(find.text('Pair Session'), findsOneWidget);
  });
}
