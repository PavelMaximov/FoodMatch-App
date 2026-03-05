import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class SwipesScreen extends StatelessWidget {
  const SwipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Свайпы',
      description: 'Здесь будут карточки блюд с like / dislike.',
    );
  }
}
