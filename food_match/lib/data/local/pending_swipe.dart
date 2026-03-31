import 'package:hive/hive.dart';

part 'pending_swipe.g.dart';

@HiveType(typeId: 1)
class PendingSwipe extends HiveObject {
  PendingSwipe({
    required this.dishId,
    required this.action,
    required this.createdAt,
  });

  @HiveField(0)
  final String dishId;

  @HiveField(1)
  final String action;

  @HiveField(2)
  final DateTime createdAt;
}
