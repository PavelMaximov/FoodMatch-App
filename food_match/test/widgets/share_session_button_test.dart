import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/shared/widgets/share_session_button.dart';

void main() {
  const channel = MethodChannel('foodmatch/session_share');
  testWidgets('one native share request while sheet is open', (tester) async {
    final dismissed = Completer<void>();
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      await dismissed.future;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ShareSessionButton(code: 'AB12CD')),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(
      calls.single.arguments['url'],
      'foodmatch://connect-couple?code=AB12CD',
    );
    expect(calls.single.arguments['text'], contains('AB12CD'));
    dismissed.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable native sharing offers copying code', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => throw PlatformException(code: 'share_unavailable'),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ShareSessionButton(code: 'AB12CD')),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    expect(
      find.text('Unable to share. Copy the invitation code instead.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
