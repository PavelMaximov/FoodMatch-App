import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/match_history.dart';
import 'package:food_match/features/profile/logic/match_history_provider.dart';

void main() {
  test('disposing during load does not notify after disposal', () async {
    final Completer<MatchHistory> completer = Completer<MatchHistory>();
    final MatchHistoryProvider provider = MatchHistoryProvider.withLoader(
      () => completer.future,
    );
    int notifications = 0;
    provider.addListener(() => notifications++);

    final Future<void> load = provider.load();
    expect(notifications, 1);
    provider.dispose();
    completer.complete(const MatchHistory(solo: [], pair: []));

    await expectLater(load, completes);
    expect(notifications, 1);
  });

  test('overlapping loads share one request', () async {
    final List<Completer<MatchHistory>> requests = <Completer<MatchHistory>>[];
    final MatchHistoryProvider provider = MatchHistoryProvider.withLoader(() {
      final Completer<MatchHistory> request = Completer<MatchHistory>();
      requests.add(request);
      return request.future;
    });

    final Future<void> first = provider.load();
    final Future<void> second = provider.load();
    expect(requests, hasLength(1));
    expect(identical(first, second), isTrue);
    requests[0].complete(const MatchHistory(solo: [], pair: []));
    await Future.wait([first, second]);

    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
    provider.dispose();
  });
}
