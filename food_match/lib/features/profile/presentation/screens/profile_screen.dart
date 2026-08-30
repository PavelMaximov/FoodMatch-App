import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/notification_theme.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/food_match_notifications.dart';
import '../../../../data/models/user.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../../shared/widgets/media/safe_avatar_image.dart';
import '../widgets/profile_premium_banner.dart';

/// Account dashboard. Product preferences intentionally live on the Settings
/// screen while identity changes live behind the profile card's Edit action.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            _ProfileCard(name: name, email: email, avatarUrl: user?.avatarUrl, onEdit: () => context.push('/profile/edit')),
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
            const _SectionLabel('FoodMatch'),
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
  const _ProfileCard({required this.name, required this.email, required this.avatarUrl, required this.onEdit});
  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _Surface(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: <Widget>[
        CircleAvatar(
          radius: 32,
          backgroundColor: context.fmColors.primary,
          child: avatarUrl?.trim().isNotEmpty == true
              ? SafeAvatarImage(imageUrl: avatarUrl, size: 64)
              : Text(name.characters.first.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
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
