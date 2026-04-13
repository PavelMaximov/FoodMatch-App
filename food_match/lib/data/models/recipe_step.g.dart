// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_step.dart';

RecipeStep _$RecipeStepFromJson(Map<String, dynamic> json) => RecipeStep(
      step: (json['step'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
    );

Map<String, dynamic> _$RecipeStepToJson(RecipeStep instance) =>
    <String, dynamic>{
      'step': instance.step,
      'text': instance.text,
    };
