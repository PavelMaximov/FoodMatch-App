import 'package:json_annotation/json_annotation.dart';

import 'recipe.dart';

part 'dish.g.dart';

@JsonSerializable()
class Dish {
  const Dish({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.cuisine,
    required this.tags,
    required this.source,
    this.externalId,
    required this.createdBy,
    this.recipe,
  });

  @JsonKey(name: '_id')
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String cuisine;
  final List<String> tags;
  final String source;
  final String? externalId;
  final String createdBy;
  final Recipe? recipe;

  factory Dish.fromJson(Map<String, dynamic> json) => _$DishFromJson(json);

  Map<String, dynamic> toJson() => _$DishToJson(this);
}
