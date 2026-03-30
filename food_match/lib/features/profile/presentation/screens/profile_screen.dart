import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final CoupleProvider couple = context.watch<CoupleProvider>();
    final user = auth.currentUser;
    final String displayName = user?.displayName.isNotEmpty == true ? user!.displayName : 'No name';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          children: <Widget>[
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              'Profile',
              style: GoogleFonts.pacifico(
                fontSize: 32,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            Card(
              elevation: 2,
              shadowColor: AppColors.cardShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        displayName[0].toUpperCase(),
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayName,
                            style: GoogleFonts.nunito(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(user?.email ?? '-', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            Text('Session', style: AppTextStyles.sectionHeader),
            const SizedBox(height: 12),
            if (couple.currentCouple != null)
              Card(
                elevation: 2,
                shadowColor: AppColors.cardShadow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Invite code: ${couple.currentCouple!.inviteCode}',
                        style: AppTextStyles.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Members: ${couple.currentCouple!.members.length}/2',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: 'Leave session',
                        isOutlined: true,
                        onPressed: () async {
                          final bool confirmed = await _showConfirmDialog(
                            context,
                            'Leave session?',
                            'Are you sure you want to leave this session?',
                          );
                          if (!confirmed || !context.mounted) return;
                          await context.read<CoupleProvider>().leaveCouple();
                          if (context.mounted) {
                            SnackBarUtils.showSuccess(context, 'You left the session');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              AppButton(
                text: 'Connect to session',
                onPressed: () => context.push('/connect-couple'),
              ),
            const SizedBox(height: AppDimensions.paddingL),
            AppButton(
              text: 'Log out',
              isOutlined: true,
              onPressed: () async {
                final bool confirmed = await _showConfirmDialog(
                  context,
                  'Log out?',
                  'Are you sure you want to log out?',
                );
                if (!confirmed || !context.mounted) return;
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  SnackBarUtils.showSuccess(context, 'You have logged out');
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: AppDimensions.paddingL),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
