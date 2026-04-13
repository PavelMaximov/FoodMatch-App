import 'package:json_annotation/json_annotation.dart';

part 'recipe_step.g.dart';

@JsonSerializable()
class RecipeStep {
  const RecipeStep({required this.step, required this.text});

  final int step;
  final String text;

  factory RecipeStep.fromJson(Map<String, dynamic> json) =>
      _$RecipeStepFromJson(json);

  Map<String, dynamic> toJson() => _$RecipeStepToJson(this);
}
