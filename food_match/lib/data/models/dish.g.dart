// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish.dart';

Dish _$DishFromJson(Map<String, dynamic> json) => Dish(
      id: json['_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      cuisine: json['cuisine'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      source: json['source'] as String,
      externalId: json['externalId'] as String?,
      createdBy: json['createdBy'] as String,
      recipe: json['recipe'] == null
          ? null
          : Recipe.fromJson(json['recipe'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DishToJson(Dish instance) => <String, dynamic>{
      '_id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'imageUrl': instance.imageUrl,
      'cuisine': instance.cuisine,
      'tags': instance.tags,
      'source': instance.source,
      'externalId': instance.externalId,
      'createdBy': instance.createdBy,
      'recipe': instance.recipe,
    };
