import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads a local subset of FoodMatch's font for deterministic layout metrics.
Future<void> loadPremiumTestFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = ByteData.sublistView(
    await File('test/fixtures/fonts/Nunito-test.ttf').readAsBytes(),
  );
  for (final variant in ['regular', '600', '700', '800', '900']) {
    await (FontLoader('Nunito_$variant')..addFont(Future.value(bytes))).load();
  }
}
