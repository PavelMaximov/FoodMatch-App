import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/swipe.dart';

void main() {
  test('Swipe.fromJson parses fields', () {
    final model = Swipe.fromJson({
      '_id': 's1',
      'userId': 'u1',
      'coupleId': 'c1',
      'dishId': 'd1',
      'action': 'like',
    });

    expect(model.id, 's1');
    expect(model.action, 'like');
  });
}
