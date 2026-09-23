import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/router/app_router.dart';
import '../helpers/pump_food_match_test_app.dart';

void main() {
  testWidgets('non-adjacent root tabs switch directly', (
    WidgetTester tester,
  ) async {
    await pumpFoodMatchTestApp(tester, const _TabStackHarness());

    expect(find.text('Recipes').hitTestable(), findsOneWidget);
    expect(find.text('Matches').hitTestable(), findsNothing);
    expect(find.text('Profile').hitTestable(), findsNothing);

    await tester.tap(find.byKey(const Key('show-profile')));
    await tester.pump();

    expect(
      tester.widget<IndexedStack>(find.byKey(const Key('root-tab-stack'))).index,
      4,
    );
    expect(find.byType(PageView), findsNothing);
    expect(find.text('Recipes').hitTestable(), findsNothing);
    expect(find.text('Matches').hitTestable(), findsNothing);
    expect(find.text('Swipes').hitTestable(), findsNothing);
    expect(find.text('Add dishes').hitTestable(), findsNothing);
    expect(find.text('Profile').hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const Key('show-recipes')));
    await tester.pump();

    expect(
      tester.widget<IndexedStack>(find.byKey(const Key('root-tab-stack'))).index,
      0,
    );
    expect(find.text('Recipes').hitTestable(), findsOneWidget);
    expect(find.text('Profile').hitTestable(), findsNothing);
  });
}

class _TabStackHarness extends StatefulWidget {
  const _TabStackHarness();

  @override
  State<_TabStackHarness> createState() => _TabStackHarnessState();
}

class _TabStackHarnessState extends State<_TabStackHarness> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RootTabBranchStack(
        currentIndex: _currentIndex,
        children: const <Widget>[
          Center(child: Text('Recipes')),
          Center(child: Text('Matches')),
          Center(child: Text('Swipes')),
          Center(child: Text('Add dishes')),
          Center(child: Text('Profile')),
        ],
      ),
      bottomNavigationBar: Row(
        children: <Widget>[
          TextButton(
            key: const Key('show-recipes'),
            onPressed: () => setState(() => _currentIndex = 0),
            child: const Text('Show recipes'),
          ),
          TextButton(
            key: const Key('show-profile'),
            onPressed: () => setState(() => _currentIndex = 4),
            child: const Text('Show profile'),
          ),
        ],
      ),
    );
  }
}
