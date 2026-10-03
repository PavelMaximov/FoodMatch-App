import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/swipes/presentation/widgets/swipeable_stack.dart';

void main() {
  testWidgets('reset cancels a button swipe without sending the action', (tester) async {
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
    expect(swipes, 0);
    final next = key.currentState!.swipeLeftFromButton();
    await tester.pumpAndSettle();
    await next;
    expect(swipes, 1);
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
