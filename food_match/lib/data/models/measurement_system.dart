import 'dart:ui';

enum MeasurementSystemPreference { auto, metric, imperial }
enum MeasurementSystem { metric, imperial }

extension MeasurementSystemPreferenceValue on MeasurementSystemPreference {
  String get value => name;
  String get label => name[0].toUpperCase() + name.substring(1);

  static MeasurementSystemPreference parse(Object? value) =>
      MeasurementSystemPreference.values.firstWhere(
        (item) => item.name == value,
        orElse: () => MeasurementSystemPreference.auto,
      );
}

MeasurementSystem resolveMeasurementSystem(
  MeasurementSystemPreference preference, {
  Locale? locale,
}) {
  if (preference == MeasurementSystemPreference.metric) return MeasurementSystem.metric;
  if (preference == MeasurementSystemPreference.imperial) return MeasurementSystem.imperial;
  final country = (locale?.countryCode ?? '').toUpperCase();
  return const {'US', 'LR', 'MM'}.contains(country)
      ? MeasurementSystem.imperial
      : MeasurementSystem.metric;
}
