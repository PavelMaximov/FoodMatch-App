import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Login',
      description: 'Экран входа (MVP заглушка).',
      actions: <Widget>[
        ElevatedButton(
          onPressed: () => context.go('/swipes'),
          child: const Text('Войти (в MVP)'),
        ),
        OutlinedButton(
          onPressed: () => context.go('/register'),
          child: const Text('К регистрации'),
        ),
      ],
    );
  }
}
