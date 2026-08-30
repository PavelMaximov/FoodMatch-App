import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/notification_theme.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/food_match_notifications.dart';
import '../../../../data/models/measurement_system.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../matches/logic/match_provider.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return _DetailScaffold(title: 'Edit Profile', children: <Widget>[
      _ActionCard(children: <Widget>[
        _DetailRow(icon: Icons.person_outline, title: 'Name', value: user?.displayName ?? 'Name', onTap: () => _notice(context, 'Name editing will be available soon.')),
        _DetailRow(icon: Icons.email_outlined, title: 'Email', value: user?.email ?? '', onTap: () => _showInfo(context, 'Change Email', 'Email changes may require confirmation. This feature will be available soon.')),
        _DetailRow(icon: Icons.lock_outline, title: 'Password', onTap: () => _showInfo(context, 'Change Password', 'Password change will be available soon.')),
      ]),
    ]);
  }
}

class MatchHistoryScreen extends StatelessWidget {
  const MatchHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final matches = context.watch<MatchProvider>().matches;
    return _DetailScaffold(
      title: 'Match History',
      children: matches.isEmpty
          ? <Widget>[
              const SizedBox(height: 100),
              Icon(Icons.history_rounded, size: 64, color: context.fmColors.textMuted),
              const SizedBox(height: 16),
              Center(child: Text('No matches yet', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800))),
              const SizedBox(height: 6),
              Center(child: Text('Your matched dishes will appear here.', style: TextStyle(color: context.fmColors.textMuted))),
            ]
          : <Widget>[
              _ActionCard(children: <Widget>[
                for (final match in matches)
                  ListTile(leading: const Icon(Icons.restaurant_rounded), title: Text(match.dish.name), subtitle: const Text('Matched dish')),
              ]),
            ],
    );
  }
}

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => _DetailScaffold(title: 'Settings', children: <Widget>[
    const _Header('Subscription'),
    _ActionCard(children: <Widget>[
      const ListTile(
        leading: Icon(Icons.workspace_premium_outlined),
        title: Text('No active subscription'),
        subtitle: Text('Use the Premium banner on your Profile to learn more.'),
      ),
    ]),
    const _Header('Notifications'),
    _ActionCard(children: <Widget>[
      SwitchListTile(value: false, onChanged: null, secondary: const Icon(Icons.notifications_outlined), title: const Text('Push Notifications'), subtitle: const Text('Notification controls are coming soon.')),
    ]),
    const _Header('General'),
    _ActionCard(children: <Widget>[
      _DetailRow(icon: Icons.language_rounded, title: 'Language', value: 'English', onTap: () => _showInfo(context, 'Language', 'FoodMatch is currently available in English. More languages are planned.')),
      _DetailRow(icon: Icons.straighten_outlined, title: 'Units', value: context.watch<AuthProvider>().measurementSystemPreference.label, onTap: () => _showUnits(context)),
      _DetailRow(icon: Icons.palette_outlined, title: 'Color Theme', value: _themeLabel(context.watch<ThemeController>().themeMode), onTap: () => _showTheme(context)),
    ]),
    const _Header('Privacy & Data'),
    _ActionCard(children: <Widget>[
      _DetailRow(icon: Icons.download_outlined, title: 'Export Data', onTap: () => _notice(context, 'Data export will be available soon.')),
      _DetailRow(icon: Icons.privacy_tip_outlined, title: 'Consent Management', onTap: () => _notice(context, 'Consent management will be available soon.')),
    ]),
    const _Header('Account'),
    _ActionCard(children: <Widget>[
      ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right), onTap: () => _confirmDelete(context)),
    ]),
  ]);

  Future<void> _showUnits(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final value = auth.measurementSystemPreference;
    await showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const ListTile(title: Text('Units', style: TextStyle(fontWeight: FontWeight.w800))),
      for (final option in MeasurementSystemPreference.values)
        RadioListTile<MeasurementSystemPreference>(value: option, groupValue: value, title: Text(option.label), onChanged: (selected) async {
          if (selected == null) return;
          await auth.updateMeasurementSystemPreference(selected);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        }),
    ])));
  }

  Future<void> _showTheme(BuildContext context) async {
    final controller = context.read<ThemeController>();
    await showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const ListTile(title: Text('Color Theme', style: TextStyle(fontWeight: FontWeight.w800))),
      for (final option in ThemeMode.values)
        ListTile(title: Text(_themeLabel(option)), trailing: controller.themeMode == option ? const Icon(Icons.check) : null, onTap: () async {
          await controller.setThemeMode(option);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        }),
    ])));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Delete Account?'), content: const Text('This action would permanently delete your account and data.'), actions: <Widget>[
      TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete Account', style: TextStyle(color: Colors.red))),
    ]));
    if (confirmed == true && context.mounted) _notice(context, 'Account deletion is not available yet.');
  }
}

class AboutFoodMatchScreen extends StatelessWidget {
  const AboutFoodMatchScreen({super.key});
  @override
  Widget build(BuildContext context) => _DetailScaffold(title: 'About FoodMatch', children: <Widget>[
    _ActionCard(children: <Widget>[
      const _DetailRow(icon: Icons.info_outline, title: 'Version', value: '0.1.0'),
      _DetailRow(icon: Icons.policy_outlined, title: 'Privacy Policy', onTap: () => _notice(context, 'Privacy Policy will be available soon.')),
      _DetailRow(icon: Icons.description_outlined, title: 'Terms of Use', onTap: () => _notice(context, 'Terms of Use will be available soon.')),
    ]),
  ]);
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => _DetailScaffold(title: 'Help', children: <Widget>[
    _ActionCard(children: <Widget>[
      _DetailRow(icon: Icons.mail_outline, title: 'Contact Us', onTap: () => _notice(context, 'Support contact will be available soon.')),
      _DetailRow(icon: Icons.star_outline, title: 'Rate Us', onTap: () => _notice(context, 'Rating will be available after release.')),
      _DetailRow(icon: Icons.share_outlined, title: 'Share App', onTap: () => _notice(context, 'App sharing will be available after release.')),
    ]),
  ]);
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: context.fmColors.background, appBar: AppBar(backgroundColor: context.fmColors.background, title: Text(title), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())), body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: children));
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text(text, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: context.fmColors.textMuted)));
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(margin: EdgeInsets.zero, color: context.fmColors.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: context.fmColors.border)), child: Column(children: children));
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.title, this.value, this.onTap});
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon), title: Text(title), subtitle: value == null ? null : Text(value!), trailing: onTap == null && value != null ? null : const Icon(Icons.chevron_right), onTap: onTap);
}

String _themeLabel(ThemeMode mode) => switch (mode) { ThemeMode.system => 'System', ThemeMode.light => 'Light', ThemeMode.dark => 'Dark' };

void _notice(BuildContext context, String message) => FoodMatchNotifications.show(context, type: FoodMatchNotificationType.info, title: message);

Future<void> _showInfo(BuildContext context, String title, String message) => showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(title), content: Text(message), actions: <Widget>[TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('OK'))]));
