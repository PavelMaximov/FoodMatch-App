import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/couple.dart';
import '../../../../data/repositories/upload_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../matches/logic/match_provider.dart';
import '../../../swipes/logic/pre_swipe_provider.dart';
import '../../../swipes/logic/swipe_provider.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../couple/presentation/widgets/connect_session_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const Color _premiumStart = Color(0xFF614A4D);
  static const Color _premiumEnd = Color(0xFF4A436C);
  static const Color _premiumContent = Color(0xFFF7D218);
  static const double _cardRadius = 12;

  static Future<void> _openSessionSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const ConnectSessionSheet(),
    );
  }

  static Future<bool> _showConfirmDialog(
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

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingAvatar = false;
  File? _localAvatarPreview;

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) {
      return;
    }

    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) {
      return;
    }

    final File previewFile = File(image.path);
    final UploadRepository uploadRepository = context.read<UploadRepository>();
    final AuthProvider authProvider = context.read<AuthProvider>();

    setState(() {
      _localAvatarPreview = previewFile;
      _isUploadingAvatar = true;
    });
    try {
      final AvatarUploadResult result = await uploadRepository.uploadAvatar(previewFile);
      await authProvider.updateCurrentUserAvatar(
        avatarUrl: result.avatarUrl,
        avatarPublicId: result.avatarPublicId,
      );

      final String optimizedAvatarUrl = ImageUtils.getImageUrl(
        result.avatarUrl,
        usage: ImageUsage.avatar,
      );
      bool avatarPrecached = false;
      if (mounted && optimizedAvatarUrl.trim().isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(optimizedAvatarUrl), context);
          avatarPrecached = true;
        } catch (_) {
          // Keep the local preview visible if precache fails; the persisted user URL
          // will be used on the next rebuild/session without blocking upload success.
        }
      }

      if (mounted) {
        if (avatarPrecached) {
          setState(() => _localAvatarPreview = null);
        }
        SnackBarUtils.showSuccess(context, 'Avatar updated');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _localAvatarPreview = null);
        SnackBarUtils.showError(context, ErrorMessages.fromApiException(e, fallback: AppStrings.unableToUploadImage));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _localAvatarPreview = null);
        SnackBarUtils.showError(context, AppStrings.unableToUploadImage);
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _deleteAvatar() async {
    if (_isUploadingAvatar) {
      return;
    }

    final UploadRepository uploadRepository = context.read<UploadRepository>();
    final AuthProvider authProvider = context.read<AuthProvider>();

    setState(() => _isUploadingAvatar = true);
    try {
      await uploadRepository.deleteAvatar();
      await authProvider.clearCurrentUserAvatar();
      if (mounted) {
        setState(() => _localAvatarPreview = null);
      }
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Avatar deleted');
      }
    } on ApiException catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, ErrorMessages.fromApiException(e));
      }
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Unable to delete avatar');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final CoupleProvider couple = context.watch<CoupleProvider>();
    final user = auth.currentUser;
    final String displayName = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : 'Name';
    final String email = user?.email.trim().isNotEmpty == true ? user!.email : 'name@gmail.com';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          children: <Widget>[
            Text(
              AppStrings.profile,
              style: AppTextStyles.pageTitle,
            ),
            const SizedBox(height: 18),
            _UserInfoCard(
              displayName: displayName,
              email: email,
              avatarUrl: user?.avatarUrl,
              localAvatarPreview: _localAvatarPreview,
              isUploadingAvatar: _isUploadingAvatar,
              onAvatarTap: _pickAndUploadAvatar,
              onDeleteAvatar: user?.avatarUrl?.trim().isNotEmpty == true ? _deleteAvatar : null,
              onEdit: () => _showComingSoon(context, 'Edit profile'),
            ),
            const SizedBox(height: 18),
            _PremiumCta(onTap: () => _showComingSoon(context, 'Premium')),
            const SizedBox(height: 18),
            _FavoritesCard(onTap: () => context.push('/favorites')),
            const SizedBox(height: 18),
            _SettingsGroup(
              onSettings: () => _showComingSoon(context, 'Settings'),
              onAbout: () => _showComingSoon(context, 'About FoodMatch'),
              onHelp: () => _showComingSoon(context, 'Help'),
            ),
            const SizedBox(height: 18),
            _SessionCard(couple: couple),
            const SizedBox(height: 42),
            _LogoutButton(
              onPressed: () async {
                final bool confirmed = await ProfileScreen._showConfirmDialog(
                  context,
                  AppStrings.logOut,
                  AppStrings.confirmLogout,
                );
                if (!confirmed || !context.mounted) return;
                final AuthProvider authProvider = context.read<AuthProvider>();
                await authProvider.logout();
                if (context.mounted) {
                  SnackBarUtils.showSuccess(context, 'Logout');
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    SnackBarUtils.showSuccess(context, '$label coming soon');
  }
}

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({
    required this.displayName,
    required this.email,
    required this.onEdit,
    required this.onAvatarTap,
    required this.isUploadingAvatar,
    this.avatarUrl,
    this.localAvatarPreview,
    this.onDeleteAvatar,
  });

  final String displayName;
  final String email;
  final String? avatarUrl;
  final File? localAvatarPreview;
  final bool isUploadingAvatar;
  final VoidCallback onEdit;
  final VoidCallback onAvatarTap;
  final VoidCallback? onDeleteAvatar;

  @override
  Widget build(BuildContext context) {
    return _ProfileSurface(
      minHeight: 96,
      padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: isUploadingAvatar ? null : onAvatarTap,
            onLongPress: isUploadingAvatar ? null : onDeleteAvatar,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.primary,
                  backgroundImage: null,
                  child: _AvatarContent(
                    displayName: displayName,
                    avatarUrl: avatarUrl,
                    localAvatarPreview: localAvatarPreview,
                  ),
                ),
                if (isUploadingAvatar)
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 14, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Edit',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.66),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.edit,
                      size: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.66),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumCta extends StatelessWidget {
  const _PremiumCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ProfileScreen._cardRadius),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ProfileScreen._cardRadius),
            gradient: const LinearGradient(
              colors: <Color>[ProfileScreen._premiumStart, ProfileScreen._premiumEnd],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 82),
              const Icon(Icons.workspace_premium_outlined, color: ProfileScreen._premiumContent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upgrade to Premium',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: ProfileScreen._premiumContent,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: ProfileScreen._premiumContent, size: 26),
              const SizedBox(width: 18),
            ],
          ),
        ),
      ),
    );
  }
}


class _AvatarContent extends StatelessWidget {
  const _AvatarContent({
    required this.displayName,
    this.avatarUrl,
    this.localAvatarPreview,
  });

  final String displayName;
  final String? avatarUrl;
  final File? localAvatarPreview;

  @override
  Widget build(BuildContext context) {
    final File? preview = localAvatarPreview;
    if (preview != null) {
      return ClipOval(
        child: Image.file(
          preview,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
        ),
      );
    }

    final String optimizedAvatarUrl = ImageUtils.getImageUrl(
      avatarUrl,
      usage: ImageUsage.avatar,
    );
    if (optimizedAvatarUrl.trim().isNotEmpty) {
      return ClipOval(
        child: SafeNetworkImage(
          imageUrl: optimizedAvatarUrl,
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          placeholderIcon: Icons.person,
          errorIcon: Icons.person,
        ),
      );
    }

    return Text(
      displayName.characters.first.toUpperCase(),
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: 29,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FavoritesCard extends StatelessWidget {
  const _FavoritesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ProfileSurface(
      minHeight: 74,
      padding: EdgeInsets.zero,
      child: _ProfileInk(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
          child: Row(
            children: <Widget>[
              const Icon(Icons.bookmark_border, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Favorites',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You will find your favorite dishes here.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 28, color: AppColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.onSettings,
    required this.onAbout,
    required this.onHelp,
  });

  final VoidCallback onSettings;
  final VoidCallback onAbout;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return _ProfileSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          _SettingsRow(icon: Icons.settings_outlined, label: 'Settings', onTap: onSettings),
          _Separator(),
          _SettingsRow(icon: Icons.info_outline, label: 'About FoodMatch', onTap: onAbout),
          _Separator(),
          _SettingsRow(icon: Icons.help_outline, label: 'Help', onTap: onHelp),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ProfileInk(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 28, color: AppColors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.couple});

  final CoupleProvider couple;

  @override
  Widget build(BuildContext context) {
    final bool isInSession = couple.hasCouple;

    return _ProfileSurface(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.link, size: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isInSession ? 'You are in a session' : 'Create a session pair',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isInSession
                          ? 'Your partner is ${_partnerName(context, couple)}'
                          : 'Create or join an existing session',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (isInSession)
            Row(
              children: <Widget>[
                Expanded(
                  child: _SmallSessionButton(
                    label: 'Reset',
                    isLoading: couple.isLoading,
                    isOutlined: true,
                    onPressed: () async {
                      final CoupleProvider coupleProvider = context.read<CoupleProvider>();
                      await coupleProvider.resetCouple();
                      if (!context.mounted) return;
                      final String? error = coupleProvider.error;
                      if (error == null) {
                        SnackBarUtils.showSuccess(context, 'Session reset');
                      } else {
                        SnackBarUtils.showError(context, error);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SmallSessionButton(
                    label: 'Leave',
                    isLoading: couple.isLoading,
                    onPressed: () async {
                      final bool confirmed = await ProfileScreen._showConfirmDialog(
                        context,
                        'Leave',
                        AppStrings.confirmLeave,
                      );
                      if (!confirmed || !context.mounted) return;
                      final CoupleProvider coupleProvider = context.read<CoupleProvider>();
                      await coupleProvider.leaveCouple();
                      if (!context.mounted) return;
                      final String? error = coupleProvider.error;
                      if (error == null) {
                        context.read<SwipeProvider>().clearPreparedDeck();
                        context.read<PreSwipeProvider>().clearForLogout();
                        context.read<MatchProvider>().clearMatches();
                        SnackBarUtils.showSuccess(context, 'Leave');
                      } else {
                        SnackBarUtils.showError(context, error);
                      }
                    },
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () => ProfileScreen._openSessionSheet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                ),
                child: Text(
                  'Select now',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _partnerName(BuildContext context, CoupleProvider couple) {
    final String? currentUserId = context.read<AuthProvider>().currentUser?.id;
    final List<CoupleMemberProfile> profiles =
        couple.currentCouple?.memberProfiles ?? const <CoupleMemberProfile>[];
    for (final CoupleMemberProfile member in profiles) {
      final String id = member.id;
      if (id != currentUserId) {
        final String? name = member.displayName;
        if (name != null && name.trim().isNotEmpty) {
          return name.trim();
        }
        if (id.isNotEmpty) {
          return id;
        }
      }
    }
    return 'Waiting...';
  }
}

class _SmallSessionButton extends StatelessWidget {
  const _SmallSessionButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
    this.isOutlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = isOutlined
        ? OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF614A4D),
            side: const BorderSide(color: Color(0xFF614A4D), width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.zero,
          )
        : ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: EdgeInsets.zero,
          );

    final Widget child = isLoading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isOutlined ? const Color(0xFF614A4D) : Colors.white,
            ),
          )
        : Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isOutlined ? const Color(0xFF614A4D) : Colors.white,
            ),
          );

    return SizedBox(
      height: 38,
      child: isOutlined
          ? OutlinedButton(onPressed: isLoading ? null : onPressed, style: style, child: child)
          : ElevatedButton(onPressed: isLoading ? null : onPressed, style: style, child: child),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          'Logout',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _ProfileSurface extends StatelessWidget {
  const _ProfileSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.minHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: minHeight == null ? null : BoxConstraints(minHeight: minHeight!),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ProfileScreen._cardRadius),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.95)),
        // boxShadow: <BoxShadow>[
        //   BoxShadow(
        //     color: AppColors.cardShadow.withValues(alpha: 0.65),
        //     blurRadius: 10,
        //     offset: const Offset(0, 2),
        //   ),
        // ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _ProfileInk extends StatelessWidget {
  const _ProfileInk({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ProfileScreen._cardRadius),
        child: child,
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: Divider(height: 1, thickness: 1, color: AppColors.divider.withValues(alpha: 0.76)),
    );
  }
}
