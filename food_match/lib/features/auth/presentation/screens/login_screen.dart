import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/notification_theme.dart';
import '../../../../core/utils/food_match_notifications.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/food_match_ripple.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_logo_header.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../logic/auth_provider.dart';
import '../widgets/auth_staggered_entrance.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  String? _lastShownAuthError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? authError = context.watch<AuthProvider>().error;
    if (authError != null && authError != _lastShownAuthError) {
      _lastShownAuthError = authError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          FoodMatchNotifications.show(
            context,
            type: FoodMatchNotificationType.error,
            title: authError,
          );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    await auth.login(_emailController.text.trim(), _passwordController.text);

    if (!mounted) return;
    if (auth.error != null) {
      FoodMatchNotifications.show(
        context,
        type: FoodMatchNotificationType.error,
        title: auth.error!,
      );
    }
  }

  Widget _buildSocialDivider(String text) {
    return Row(
      children: <Widget>[
        Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 13,
            color: context.fmColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: context.fmColors.divider, thickness: 1)),
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
              color: context.fmColors.textPrimary,
            ),
          ),
          onTap: () => FoodMatchNotifications.show(
            context,
            type: FoodMatchNotificationType.info,
            title: AppStrings.googleSignInComingSoon,
          ),
        ),
        const SizedBox(width: 16),
        _buildSocialIcon(
          child: Icon(
            Icons.apple,
            size: 24,
            color: context.fmColors.textPrimary,
          ),
          onTap: () => FoodMatchNotifications.show(
            context,
            type: FoodMatchNotificationType.info,
            title: AppStrings.appleSignInComingSoon,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return FoodMatchRipple(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      rippleColor: context.fmColors.neutralRipple,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.fmColors.border),
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
    return FoodMatchRipple(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      rippleColor: context.fmColors.primaryRipple,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.fmColors.textPrimary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: context.fmColors.textInverse,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              actionText,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.fmColors.primary,
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
      backgroundColor: context.fmColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: AuthStaggeredEntrance(
              children: <Widget>[
                const SizedBox(height: 20),
                const AppLogoHeader(showSubtitle: true),
                Text(
                  AppStrings.login,
                  style: GoogleFonts.fredoka(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: context.fmColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  hint: AppStrings.email,
                  required: true,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.email],
                  validator: Validators.email,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  hint: AppStrings.password,
                  required: true,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const <String>[AutofillHints.password],
                  validator: Validators.password,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: context.fmColors.textMuted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (bool? value) {
                              setState(() => _rememberMe = value ?? false);
                            },
                            activeColor: context.fmColors.primary,
                            side: BorderSide(color: context.fmColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.rememberMe,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: context.fmColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    FoodMatchRipple(
                      onTap: () => context.push('/forgot-password'),
                      borderRadius: BorderRadius.circular(8),
                      rippleColor: context.fmColors.neutralRipple,
                      child: Text(
                        AppStrings.forgotPassword,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: context.fmColors.textPrimary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (BuildContext context, AuthProvider auth, _) =>
                      AppButton(
                        text: AppStrings.login,
                        isLoading: auth.isLoading,
                        onPressed: () => _login(auth),
                      ),
                ),
                const SizedBox(height: 24),
                _buildSocialDivider(AppStrings.orLoginWith),
                const SizedBox(height: 16),
                _buildSocialButtons(),
                const SizedBox(height: 24),
                _buildSwitchAuthButton(
                  text: AppStrings.noAccount,
                  actionText: AppStrings.signUp,
                  onTap: () => context.push('/register'),
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
