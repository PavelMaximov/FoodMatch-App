import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_logo_header.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../logic/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    await auth.register(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    );

    if (!mounted) return;
    if (auth.error != null) {
      SnackBarUtils.showError(context, auth.error!);
    }
  }

  Widget _buildSocialDivider(String text) {
    return Row(
      children: <Widget>[
        Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Divider(color: AppColors.divider, thickness: 1),
        ),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: <Widget>[
        _buildSocialIcon(
          child: Text(
            'G',
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          onTap: () => SnackBarUtils.showError(context, AppStrings.googleSignInComingSoon),
        ),
        const SizedBox(width: 16),
        _buildSocialIcon(
          child: const Icon(Icons.apple, size: 24, color: AppColors.textPrimary),
          onTap: () => SnackBarUtils.showError(context, AppStrings.appleSignInComingSoon),
        ),
      ],
    );
  }

  Widget _buildSocialIcon({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildSwitchAuthButton({
    required String text,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              actionText,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 40),
                const AppLogoHeader(showSubtitle: true),
                Text(
                  AppStrings.signUp,
                  style: GoogleFonts.pacifico(
                    fontSize: 28,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => SnackBarUtils.showError(context, AppStrings.photoUploadComingSoon),
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.chipBg,
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 28,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.uploadPhoto,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  hint: AppStrings.name,
                  required: true,
                  controller: _nameController,
                  validator: Validators.displayName,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  hint: AppStrings.email,
                  required: true,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  hint: AppStrings.password,
                  required: true,
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.password,
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (BuildContext context, AuthProvider auth, _) => AppButton(
                    text: AppStrings.createAccount,
                    isLoading: auth.isLoading,
                    onPressed: () => _register(auth),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSocialDivider(AppStrings.orSignUpWith),
                const SizedBox(height: 16),
                _buildSocialButtons(),
                const SizedBox(height: 24),
                _buildSwitchAuthButton(
                  text: AppStrings.haveAccount,
                  actionText: AppStrings.login,
                  onTap: () => context.go('/login'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
