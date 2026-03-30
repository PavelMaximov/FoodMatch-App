import 'package:flutter/material.dart';

import '../../../../shared/widgets/placeholder_screen.dart';
import '../../../../core/constants/app_strings.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: AppStrings.resetPasswordTitle,
      description: AppStrings.resetPasswordDesc,
    );
  }
}
