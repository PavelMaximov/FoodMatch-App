import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/theme/app_theme.dart';

Widget foodMatchTestApp(Widget child) {
  return MaterialApp(theme: AppTheme.light, home: child);
}

Future<void> pumpFoodMatchTestApp(WidgetTester tester, Widget child) {
  return tester.pumpWidget(foodMatchTestApp(child));
}
