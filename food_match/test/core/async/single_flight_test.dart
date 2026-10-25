import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/async/single_flight.dart';

void main() {
  test('publishes the future before synchronous reentry', () async {
    final flight = SingleFlight<int>();
    Future<int>? joined;
    final first = flight.run(() {
      joined = flight.run(() async => 99);
      return Future.value(1);
    });
    expect(identical(first, joined), isTrue);
    expect(await first, 1);
  });

  test('an old completion cannot clear a new generation', () async {
    final flight = SingleFlight<int>();
    final oldGate = Completer<int>();
    final newGate = Completer<int>();
    final old = flight.run(() => oldGate.future);
    flight.invalidate();
    final fresh = flight.run(() => newGate.future);
    oldGate.complete(1);
    await old;
    expect(identical(fresh, flight.run(() async => 99)), isTrue);
    newGate.complete(2);
    expect(await fresh, 2);
  });

  test('synchronous failures release the operation for retry', () async {
    final flight = SingleFlight<int>();
    await expectLater(
      flight.run(() => throw StateError('failed')),
      throwsStateError,
    );
    expect(await flight.run(() async => 2), 2);
  });
}
