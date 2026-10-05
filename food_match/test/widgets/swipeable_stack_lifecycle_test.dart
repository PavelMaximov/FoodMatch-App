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

  testWidgets('button motion survives parent index and busy-state rebuilds', (tester) async {
    final key = GlobalKey<SwipeableStackState>();
    var currentIndex = 0;
    var canSwipe = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, update) => SwipeableStack(
        key: key, itemCount: 2, currentIndex: currentIndex, canSwipe: canSwipe,
        cardBuilder: (_, index) => ColoredBox(key: ValueKey('card-$index'),
          color: Colors.orange, child: TextButton(
            onPressed: () => key.currentState!.swipeRightFromButton(),
            child: Text('like-$index'),
          )),
        onSwipe: (_, __) => update(() { currentIndex++; canSwipe = false; }),
      ),
    ))));
    await tester.tap(find.text('like-0'));
    await tester.pump();
    expect(currentIndex, 1);
    expect(find.byKey(const ValueKey('card-0')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    final outgoing = tester.widgetList<Transform>(find.ancestor(
      of: find.byKey(const ValueKey('card-0')), matching: find.byType(Transform),
    )).first;
    expect(outgoing.transform.storage[12], greaterThan(0));
    expect(find.byKey(const ValueKey('card-1')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('card-0')), findsNothing);
  });

  testWidgets('last card remains mounted for its outgoing animation', (tester) async {
    final key = GlobalKey<SwipeableStackState>();
    var currentIndex = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, update) => SwipeableStack(
        key: key, itemCount: 1, currentIndex: currentIndex, canSwipe: true,
        cardBuilder: (_, __) => const Text('last-card'),
        onSwipe: (_, __) => update(() => currentIndex++),
      ),
    ))));
    final action = key.currentState!.swipeLeftFromButton();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('last-card'), findsOneWidget);
    await tester.pumpAndSettle();
    await action;
    expect(find.text('last-card'), findsNothing);
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
