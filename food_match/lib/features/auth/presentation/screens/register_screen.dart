import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: 'Register',
      description: 'Экран регистрации (MVP заглушка).',
      actions: <Widget>[
        ElevatedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Уже есть аккаунт? Войти'),
        ),
      ],
    );
  }
}
