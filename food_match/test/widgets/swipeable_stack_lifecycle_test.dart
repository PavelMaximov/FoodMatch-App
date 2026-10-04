import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/swipes/presentation/widgets/swipeable_stack.dart';

void main() {
  testWidgets('reset cancels animation without repeating the committed button swipe', (tester) async {
    final key = GlobalKey<SwipeableStackState>();
    var swipes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SwipeableStack(
      key: key, itemCount: 2, canSwipe: true,
      cardBuilder: (_, index) => ColoredBox(color: Colors.orange, child: Text('$index')),
      onSwipe: (_, __) => swipes++,
    ))));
    final action = key.currentState!.swipeRightFromButton();
    await tester.pump(const Duration(milliseconds: 50));
    key.currentState!.resetInteractionState();
    await action;
    await tester.pumpAndSettle();
    expect(swipes, 1);
    final next = key.currentState!.swipeLeftFromButton();
    await tester.pumpAndSettle();
    await next;
    expect(swipes, 2);
  });

  testWidgets('button dispatches immediately and promotes the next card gradually', (tester) async {
    final key = GlobalKey<SwipeableStackState>();
    var swipes = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SwipeableStack(
      key: key, itemCount: 3, canSwipe: true,
      cardBuilder: (_, index) => ColoredBox(
        key: ValueKey('card-$index'), color: Colors.orange, child: Text('$index')),
      onSwipe: (_, __) => swipes++,
    ))));
    final action = key.currentState!.swipeRightFromButton();
    expect(swipes, 1);
    await tester.pump();
    double scale() => tester.widgetList<Transform>(find.ancestor(
      of: find.byKey(const ValueKey('card-1')), matching: find.byType(Transform),
    )).first.transform.storage[0];
    final start = scale();
    await tester.pump(const Duration(milliseconds: 150));
    final middle = scale();
    expect(start, closeTo(.97, .001));
    expect(middle, greaterThan(start));
    expect(middle, lessThan(1));
    await key.currentState!.swipeLeftFromButton();
    expect(swipes, 1);
    await tester.pumpAndSettle();
    await action;
    expect(scale(), closeTo(1, .001));
  });

  testWidgets('disposing the stack resolves a pending Undo animation', (tester) async {
    final key = GlobalKey<SwipeableStackState>();
    await tester.pumpWidget(MaterialApp(home: SwipeableStack(
      key: key, itemCount: 2, canSwipe: true,
      cardBuilder: (_, __) => const SizedBox.expand(),
      onSwipe: (_, __) {},
    )));
    final action = key.currentState!.playUndoReturnAnimation(direction: SwipeDirection.right);
    await tester.pumpWidget(const SizedBox());
    await action;
    expect(tester.takeException(), isNull);
  });
}
