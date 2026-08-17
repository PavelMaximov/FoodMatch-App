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
  test('serializes only the explicitly selected preference', () {
    for (final preference in MeasurementSystemPreference.values) {
      final user = User(id: '1', email: 'a@b.com', displayName: 'A', measurementSystemPreference: preference);
      expect(user.toJson()['measurementSystemPreference'], preference.name);
    }
  });

  test('auto uses only region and defaults to metric', () {
    for (final locale in const [Locale('de', 'DE'), Locale('en', 'DE'), Locale('uk', 'DE'), Locale('en', 'GB'), Locale('en', 'CA'), Locale('en')]) {
      expect(resolveMeasurementSystem(preference: MeasurementSystemPreference.auto, deviceLocale: locale), MeasurementSystem.metric);
    }
    for (final locale in const [Locale('en', 'US'), Locale('de', 'US')]) {
      expect(resolveMeasurementSystem(preference: MeasurementSystemPreference.auto, deviceLocale: locale), MeasurementSystem.imperial);
    }
    expect(resolveMeasurementSystem(preference: MeasurementSystemPreference.auto, deviceLocale: null), MeasurementSystem.metric);
    expect(resolveMeasurementSystem(preference: MeasurementSystemPreference.metric, deviceLocale: const Locale('en', 'US')), MeasurementSystem.metric);
    expect(resolveMeasurementSystem(preference: MeasurementSystemPreference.imperial, deviceLocale: const Locale('de', 'DE')), MeasurementSystem.imperial);
  });
}
