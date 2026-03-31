import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/core/utils/validators.dart';

void main() {
  test('email validator', () {
    expect(Validators.email(null), isNotNull);
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('invalid'), isNotNull);
    expect(Validators.email('test@test.com'), isNull);
  });
}
