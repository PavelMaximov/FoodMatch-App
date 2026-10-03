import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/swipes/presentation/controllers/swipe_action_controller.dart';
import 'package:food_match/features/swipes/presentation/controllers/swipe_polling_controller.dart';
import 'package:food_match/features/swipes/presentation/controllers/swipe_effect_scheduler.dart';

void main() {
  test('card actions reject double taps and release on failure', () async {
    final controller = SwipeActionController();
    final pending = Completer<void>();
    var calls = 0;
    final first = controller.run(() { calls++; return pending.future; });
    await controller.run(() async { calls++; });
    expect(calls, 1);
    expect(controller.isBusy, isTrue);
    final failure = expectLater(first, throwsStateError);
    pending.completeError(StateError('failed'));
    await failure;
    expect(controller.isBusy, isFalse);
    await controller.run(() async { calls++; });
    expect(calls, 2);
    controller.dispose();
  });

  test('old action cannot unlock a new action after auth reset', () async {
    final controller = SwipeActionController();
    final old = Completer<void>();
    final fresh = Completer<void>();
    final oldAction = controller.run(() => old.future);
    controller.reset();
    final freshAction = controller.run(() => fresh.future);
    old.complete();
    await oldAction;
    expect(controller.isBusy, isTrue);
    fresh.complete();
    await freshAction;
    expect(controller.isBusy, isFalse);
    controller.dispose();
  });

  test('disposing while an action is pending emits no late notification', () async {
    final controller = SwipeActionController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    final pending = Completer<void>();
    final action = controller.run(() => pending.future);
    controller.dispose();
    pending.complete();
    await action;
    expect(notifications, 1);
  });

  testWidgets('polling coalesces slow requests and stops its timers', (tester) async {
    final errors = <Object>[];
    final polling = SwipePollingController(onError: (error, _) => errors.add(error));
    final pending = Completer<void>();
    var calls = 0;
    polling.start('matches', const Duration(seconds: 1), () { calls++; return pending.future; });
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(calls, 1);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    polling.stopAll();
    await tester.pump(const Duration(seconds: 5));
    expect(calls, 2);
    expect(errors, isEmpty);
    polling.dispose();
  });

  test('failed poll releases the channel for retry', () async {
    final errors = <Object>[];
    final polling = SwipePollingController(onError: (error, _) => errors.add(error));
    await polling.run('matches', () async { throw StateError('offline'); });
    var retried = false;
    await polling.run('matches', () async { retried = true; });
    expect(errors, hasLength(1));
    expect(retried, isTrue);
    polling.dispose();
  });

  testWidgets('effects run once per frame and reset discards old work', (tester) async {
    final effects = SwipeEffectScheduler();
    var calls = 0;
    effects.schedule('invite', () => calls += 100);
    effects.schedule('invite', () => calls++);
    await tester.pump();
    expect(calls, 1);
    effects.schedule('invite', () => calls += 100);
    effects.reset();
    effects.schedule('invite', () => calls++);
    await tester.pump();
    expect(calls, 2);
    effects.schedule('invite', () => calls++);
    effects.dispose();
    await tester.pump();
    expect(calls, 2);
  });
}
