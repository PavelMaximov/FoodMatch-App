import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/notification_theme.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/food_match_notifications.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/user.dart';
import '../../../../data/repositories/upload_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../../shared/widgets/media/safe_avatar_image.dart';
import '../widgets/profile_premium_banner.dart';

/// Account dashboard. Product preferences intentionally live on the Settings
/// screen while identity changes live behind the profile card's Edit action.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingAvatar = false;
  File? _localAvatarPreview;

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;
    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (image == null || !mounted) return;
    final File previewFile = File(image.path);
    setState(() {
      _localAvatarPreview = previewFile;
      _isUploadingAvatar = true;
    });
    try {
      final AvatarUploadResult result = await context
          .read<UploadRepository>()
          .uploadAvatar(previewFile);
      await context.read<AuthProvider>().updateCurrentUserAvatar(
        avatarUrl: result.avatarUrl,
        avatarPublicId: result.avatarPublicId,
      );
      bool avatarPrecached = false;
      final String optimizedUrl = ImageUtils.getImageUrl(
        result.avatarUrl,
        usage: ImageUsage.avatarLarge,
      );
      if (mounted && optimizedUrl.isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(optimizedUrl), context);
          avatarPrecached = true;
        } catch (_) {
          // The persisted URL is still valid; keep the local preview meanwhile.
        }
      }
      if (mounted) {
        if (avatarPrecached) setState(() => _localAvatarPreview = null);
        FoodMatchNotifications.show(
          context,
          type: FoodMatchNotificationType.success,
          title: 'Avatar updated',
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _localAvatarPreview = null);
        FoodMatchNotifications.show(
          context,
          type: FoodMatchNotificationType.error,
          title: ErrorMessages.fromApiException(
            error,
            fallback: AppStrings.unableToUploadImage,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _localAvatarPreview = null);
        FoodMatchNotifications.show(
          context,
          type: FoodMatchNotificationType.error,
          title: AppStrings.unableToUploadImage,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    if (_isUploadingAvatar) return;
    setState(() => _isUploadingAvatar = true);
    try {
      await context.read<UploadRepository>().deleteAvatar();
      await context.read<AuthProvider>().clearCurrentUserAvatar();
      if (!mounted) return;
      setState(() => _localAvatarPreview = null);
      FoodMatchNotifications.show(
        context,
        type: FoodMatchNotificationType.destructive,
        title: 'Photo removed',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      FoodMatchNotifications.show(
        context,
        type: FoodMatchNotificationType.error,
        title: ErrorMessages.fromApiException(error),
      );
    } catch (_) {
      if (!mounted) return;
      FoodMatchNotifications.show(
        context,
        type: FoodMatchNotificationType.error,
        title: 'Unable to remove photo',
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _showAvatarActions({required bool hasAvatar}) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Change Photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndUploadAvatar();
              },
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _logOut(BuildContext context) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Log Out'),
            content: const Text('Are you sure you want to log out?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final User? user = context.select<AuthProvider, User?>((p) => p.currentUser);
    final CoupleProvider couple = context.watch<CoupleProvider>();
    final String name = user?.displayName.trim().isNotEmpty == true
        ? user!.displayName.trim()
        : 'Name';
    final String email = user?.email.trim().isNotEmpty == true
        ? user!.email
        : 'Email';

    return Scaffold(
      backgroundColor: context.fmColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: <Widget>[
            Text('Profile', style: AppTextStyles.pageTitle.copyWith(color: context.fmColors.textPrimary)),
            const SizedBox(height: 18),
            _ProfileCard(
              name: name,
              email: email,
              avatarUrl: user?.avatarUrl,
              localAvatarPreview: _localAvatarPreview,
              isUploadingAvatar: _isUploadingAvatar,
              onAvatarTap: () => _showAvatarActions(
                hasAvatar: user?.avatarUrl?.trim().isNotEmpty == true,
              ),
              onEdit: () => context.push('/profile/edit'),
            ),
            const SizedBox(height: 16),
            ProfilePremiumBanner(
              onTap: () => _notice(context, 'Premium subscriptions will be available soon.'),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Your FoodMatch'),
            _NavigationGroup(children: <Widget>[
              _DashboardRow(icon: Icons.bookmark_border_rounded, label: 'Favorites', onTap: () => context.push('/favorites')),
              _DashboardRow(icon: Icons.shopping_basket_outlined, label: 'Grocery List', onTap: () => context.push('/shopping-list')),
              _DashboardRow(icon: Icons.history_rounded, label: 'Match History', onTap: () => context.push('/profile/match-history')),
            ]),
            const SizedBox(height: 24),
            const _SectionLabel('App & Support'),
            _NavigationGroup(children: <Widget>[
              _DashboardRow(icon: Icons.settings_outlined, label: 'Settings', onTap: () => context.push('/profile/settings')),
              _DashboardRow(icon: Icons.info_outline_rounded, label: 'About FoodMatch', onTap: () => context.push('/profile/about')),
              _DashboardRow(icon: Icons.help_outline_rounded, label: 'Help', onTap: () => context.push('/profile/help')),
            ]),
            const SizedBox(height: 24),
            const _SectionLabel('Session'),
            _Surface(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.link_rounded),
                title: Text(couple.hasCouple ? 'Paired session active' : 'No active paired session'),
                subtitle: Text(couple.hasCouple ? 'Manage your session from the Swipe page.' : 'Start or join a session from the Swipe page.'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _logOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: context.fmColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

void _notice(BuildContext context, String message) {
  FoodMatchNotifications.show(context, type: FoodMatchNotificationType.info, title: message);
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email, required this.avatarUrl, required this.localAvatarPreview, required this.isUploadingAvatar, required this.onAvatarTap, required this.onEdit});
  final String name;
  final String email;
  final String? avatarUrl;
  final File? localAvatarPreview;
  final bool isUploadingAvatar;
  final VoidCallback onAvatarTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _Surface(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: <Widget>[
        GestureDetector(
          key: const Key('change-avatar-button'),
          onTap: isUploadingAvatar ? null : onAvatarTap,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CircleAvatar(
                radius: 32,
                backgroundColor: context.fmColors.primary,
                child: localAvatarPreview != null || avatarUrl?.trim().isNotEmpty == true
                    ? SafeAvatarImage(imageUrl: avatarUrl, localPreview: localAvatarPreview, size: 64)
                    : Text(name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              ),
              if (isUploadingAvatar)
                const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              else
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: context.fmColors.card, shape: BoxShape.circle),
                    child: Icon(Icons.camera_alt_rounded, size: 14, color: context.fmColors.primary),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: context.fmColors.textPrimary)),
          Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(color: context.fmColors.textMuted)),
        ])),
        TextButton.icon(key: const Key('edit-profile-button'), onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
      ]),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: context.fmColors.textMuted)),
  );
}

class _NavigationGroup extends StatelessWidget {
  const _NavigationGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => _Surface(
    child: Column(children: <Widget>[
      for (int i = 0; i < children.length; i++) ...<Widget>[
        children[i],
        if (i != children.length - 1) Divider(height: 1, color: context.fmColors.divider),
      ],
    ]),
  );
}

class _DashboardRow extends StatelessWidget {
  const _DashboardRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: context.fmColors.textPrimary),
    title: Text(label, style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: context.fmColors.textPrimary)),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: context.fmColors.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: context.fmColors.border)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
