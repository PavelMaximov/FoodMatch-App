import 'package:flutter/material.dart';

class RecipeDishLayoutStyle {
  const RecipeDishLayoutStyle._();

  static const int defaultGridColumns = 2;
  static const EdgeInsets gridPadding = EdgeInsets.all(16);
  static const double gridChildAspectRatio = 0.72;
  static const double gridCrossAxisSpacing = 12;
  static const double gridMainAxisSpacing = 12;

  static SliverGridDelegate gridDelegate({
    required int crossAxisCount,
    double childAspectRatio = gridChildAspectRatio,
    double crossAxisSpacing = gridCrossAxisSpacing,
    double mainAxisSpacing = gridMainAxisSpacing,
  }) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }
}
