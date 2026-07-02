import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../logic/auth_provider.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.currentUser?.email ?? 'your email address';

    final colors = context.fmColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 72, color: colors.primary),
              const SizedBox(height: 24),
              Text('Check your email', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colors.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('We sent a verification link to $email. Verify your address, then come back and check again.', textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary)),
              const SizedBox(height: 32),
              AppButton(text: 'I verified, check again', onPressed: auth.checkVerificationStatus),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: auth.resendVerification, child: const Text('Resend email')),
              const SizedBox(height: 12),
              TextButton(onPressed: auth.logout, child: const Text('Logout')),
            ],
          ),
        ),
      ),
    );
  }
}
