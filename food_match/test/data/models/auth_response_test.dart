import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/auth_response.dart';

void main() {
  test('AuthResponse.fromJson parses token and user', () {
    final model = AuthResponse.fromJson({
      'token': 'jwt',
      'user': {
        '_id': 'u1',
        'email': 'mail@test.com',
        'displayName': 'Name',
      },
    });

    expect(model.token, 'jwt');
    expect(model.user!.id, 'u1');
  });

  test('AuthResponse.fromJson parses token-only response', () {
    final model = AuthResponse.fromJson({'token': 'jwt'});

    expect(model.token, 'jwt');
    expect(model.user, isNull);
  });
}
