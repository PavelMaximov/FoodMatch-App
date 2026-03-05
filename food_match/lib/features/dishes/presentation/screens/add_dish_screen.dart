import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class AddDishScreen extends StatelessWidget {
  const AddDishScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Добавить блюдо',
      description: 'Форма добавления своего блюда (MVP заглушка).',
    );
  }
}
