import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../logic/auth_provider.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final email = auth.currentUser?.email ?? 'your email address';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 72, color: AppColors.primary),
              const SizedBox(height: 24),
              Text('Check your email', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('We sent a verification link to $email. Verify your address, then come back and check again.', textAlign: TextAlign.center),
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
