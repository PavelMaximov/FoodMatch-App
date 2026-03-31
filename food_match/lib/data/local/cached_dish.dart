import 'package:hive/hive.dart';

part 'cached_dish.g.dart';

@HiveType(typeId: 0)
class CachedDish extends HiveObject {
  CachedDish({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.cuisine,
    required this.tags,
    required this.source,
    this.externalId,
    this.createdBy,
    this.recipeIngredientsJson,
    this.recipeStepsJson,
    required this.cachedAt,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String imageUrl;

  @HiveField(4)
  final String cuisine;

  @HiveField(5)
  final List<String> tags;

  @HiveField(6)
  final String source;

  @HiveField(7)
  final String? externalId;

  @HiveField(8)
  final String? createdBy;

  @HiveField(9)
  final String? recipeIngredientsJson;

  @HiveField(10)
  final String? recipeStepsJson;

  @HiveField(11)
  final DateTime cachedAt;
}
