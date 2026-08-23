import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/user.dart';
import 'package:food_match/data/models/measurement_system.dart';

void main() {
  test('User.fromJson parses _id', () {
    final user = User.fromJson({
      '_id': 'u1',
      'email': 'demo@test.com',
      'displayName': 'Demo',
      'coupleId': 'c1',
    });

    expect(user.id, 'u1');
    expect(user.coupleId, 'c1');
  });

  test('User.fromJson parses id fallback', () {
    final user = User.fromJson({
      'id': 'u2',
      'email': 'demo2@test.com',
      'displayName': 'Demo2',
    });

    expect(user.id, 'u2');
    expect(user.coupleId, isNull);
  });

  test('User.fromJson accepts Supabase snake_case profile fields', () {
    final User user = User.fromJson(<String, dynamic>{
      'id': 'runtime-id',
      'email': 'qa@example.com',
      'display_name': 'QA User',
      'avatar_url': 'https://example.com/avatar.jpg',
      'email_verified': true,
      'measurement_system_preference': 'metric',
    });

    expect(user.displayName, 'QA User');
    expect(user.avatarUrl, 'https://example.com/avatar.jpg');
    expect(
      user.measurementSystemPreference,
      MeasurementSystemPreference.metric,
    );
  });
}
