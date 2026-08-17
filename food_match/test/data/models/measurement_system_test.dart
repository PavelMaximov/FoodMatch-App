import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/measurement_system.dart';
import 'package:food_match/data/models/user.dart';

void main() {
  test('user preference defaults and unsupported values safely to auto', () {
    expect(const User(id: '1', email: 'a@b.com', displayName: 'A').measurementSystemPreference,
        MeasurementSystemPreference.auto);
    expect(MeasurementSystemPreferenceValue.parse('unsupported'), MeasurementSystemPreference.auto);
  });

  test('auto uses imperial countries and metric otherwise', () {
    expect(resolveMeasurementSystem(MeasurementSystemPreference.auto, locale: const Locale('en', 'US')),
        MeasurementSystem.imperial);
    expect(resolveMeasurementSystem(MeasurementSystemPreference.auto, locale: const Locale('de', 'DE')),
        MeasurementSystem.metric);
    expect(resolveMeasurementSystem(MeasurementSystemPreference.metric, locale: const Locale('en', 'US')),
        MeasurementSystem.metric);
  });
}
