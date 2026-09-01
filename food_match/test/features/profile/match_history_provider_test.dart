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

  test('a newer overlapping load wins', () async {
    final List<Completer<MatchHistory>> requests = <Completer<MatchHistory>>[];
    final MatchHistoryProvider provider = MatchHistoryProvider.withLoader(() {
      final Completer<MatchHistory> request = Completer<MatchHistory>();
      requests.add(request);
      return request.future;
    });

    final Future<void> first = provider.load();
    final Future<void> second = provider.load();
    requests[1].complete(const MatchHistory(solo: [], pair: []));
    await second;
    requests[0].complete(const MatchHistory(solo: [], pair: []));
    await first;

    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
    provider.dispose();
  });
}
