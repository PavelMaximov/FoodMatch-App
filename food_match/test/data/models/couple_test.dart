import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/couple.dart';

void main() {
  test('Couple.fromJson parses fields', () {
    final model = Couple.fromJson({
      '_id': 'c1',
      'inviteCode': 'ABC123',
      'members': ['u1', 'u2'],
    });

    expect(model.id, 'c1');
    expect(model.members.length, 2);
  });

  test('Couple.fromJson parses populated member objects', () {
    final model = Couple.fromJson({
      '_id': 'c1',
      'inviteCode': 'ABC123',
      'members': [
        {'_id': 'u1', 'displayName': 'Alex'},
        {'id': 'u2', 'displayName': 'Sam'},
      ],
    });

    expect(model.members, <String>['u1', 'u2']);
  });
}
