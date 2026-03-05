import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class MatchOverlayScreen extends StatelessWidget {
  const MatchOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'New Match!',
      description: 'Экран overlay/dialog при новом совпадении.',
    );
  }
}
