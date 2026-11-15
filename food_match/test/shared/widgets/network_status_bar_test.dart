import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/shared/widgets/network_status_bar.dart';

void main() {
  testWidgets('German offline message fits narrow screens', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('de'),
        home: Scaffold(
          body: SizedBox(width: 360, child: NetworkStatusBar.offlineForTest()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Der Server ist derzeit nicht erreichbar. Bitte versuche es später erneut.',
      ),
      findsOneWidget,
    );
  });
}
