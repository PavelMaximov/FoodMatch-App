import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/data/models/swipe_stats.dart';

void main() {
  test('SwipeStats.fromJson parses fields', () {
    final model = SwipeStats.fromJson({'likes': 2, 'dislikes': 3});

    expect(model.likes, 2);
    expect(model.dislikes, 3);
  });
}
