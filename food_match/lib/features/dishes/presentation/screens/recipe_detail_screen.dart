import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({required this.dishId, super.key});

  final String dishId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Recipe Detail',
      description: 'Детали рецепта для dishId: $dishId',
    );
  }
}
