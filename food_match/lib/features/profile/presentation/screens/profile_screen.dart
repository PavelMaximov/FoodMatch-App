import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../data/repositories/upload_repository.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../couple/presentation/widgets/connect_session_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isAvatarLoading = false;

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _isAvatarLoading = true);
    try {
      final uploadRepo = context.read<UploadRepository>();
      final file = File(image.path);
      final prepared = await uploadRepo.prepareAvatarUpload(file);
      await uploadRepo.uploadFileToSignedUrl(
        uploadUrl: prepared.uploadUrl,
        mimeType: prepared.mimeType,
        file: file,
        headers: prepared.headers,
      );

      await uploadRepo.confirmAvatarUpload(
        avatarKey: prepared.objectKey,
        avatarMimeType: prepared.mimeType,
        avatarSize: prepared.sizeBytes,
      );

      await context.read<AuthProvider>().refreshCurrentUser();
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Avatar updated');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to upload avatar');
      }
    } finally {
      if (mounted) {
        setState(() => _isAvatarLoading = false);
      }
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _isAvatarLoading = true);
    try {
      await context.read<UploadRepository>().deleteAvatar();
      await context.read<AuthProvider>().refreshCurrentUser();
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Avatar deleted');
      }
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to delete avatar');
      }
    } finally {
      if (mounted) {
        setState(() => _isAvatarLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final CoupleProvider couple = context.watch<CoupleProvider>();
    final user = auth.currentUser;
    final String displayName = user?.displayName.isNotEmpty == true ? user!.displayName : AppStrings.yourPartner;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          children: <Widget>[
            const SizedBox(height: AppDimensions.paddingS),
            Text(
              AppStrings.profile,
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
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primary,
                          backgroundImage: (user?.avatarUrl ?? '').isNotEmpty
                              ? NetworkImage(user!.avatarUrl!)
                              : null,
                          child: (user?.avatarUrl ?? '').isNotEmpty
                              ? null
                              : Text(
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
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: AppButton(
                            text: 'Change avatar',
                            onPressed: _isAvatarLoading ? null : _uploadAvatar,
                            isLoading: _isAvatarLoading,
                          ),
                        ),
                        if ((user?.avatarUrl ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              text: 'Remove',
                              isOutlined: true,
                              onPressed: _isAvatarLoading ? null : _deleteAvatar,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingL),
            Text(AppStrings.session, style: AppTextStyles.sectionHeader),
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
                        '${AppStrings.inviteCode}: ${couple.currentCouple!.inviteCode}',
                        style: AppTextStyles.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${AppStrings.members}: ${couple.currentCouple!.members.length}/2',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        text: AppStrings.leaveSession,
                        isOutlined: true,
                        onPressed: () async {
                          final bool confirmed = await _showConfirmDialog(
                            context,
                            AppStrings.leaveSession,
                            AppStrings.confirmLeave,
                          );
                          if (!confirmed || !context.mounted) return;
                          await context.read<CoupleProvider>().leaveCouple();
                          if (context.mounted) {
                            SnackBarUtils.showSuccess(context, AppStrings.leaveSession);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              AppButton(
                text: AppStrings.connectToSessionBtn,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  barrierColor: Colors.black.withValues(alpha: 0.5),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (_) => const ConnectSessionSheet(),
                ),
              ),
            const SizedBox(height: AppDimensions.paddingL),
            AppButton(
              text: AppStrings.logOut,
              isOutlined: true,
              onPressed: () async {
                final bool confirmed = await _showConfirmDialog(
                  context,
                  AppStrings.logOut,
                  AppStrings.confirmLogout,
                );
                if (!confirmed || !context.mounted) return;
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  SnackBarUtils.showSuccess(context, AppStrings.logOut);
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
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  AppStrings.confirm,
                  style: TextStyle(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
