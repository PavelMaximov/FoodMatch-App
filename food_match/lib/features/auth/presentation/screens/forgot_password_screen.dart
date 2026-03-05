import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Forgot Password',
      description: 'MVP заглушка восстановления пароля.',
    );
  }
}
