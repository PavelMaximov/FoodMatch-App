import 'package:food_match/l10n/locale_controller.dart';
import 'package:food_match/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/notification_theme.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/food_match_notifications.dart';
import '../../../../core/assets/app_empty_state_assets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/food_match_empty_state_image.dart';
import '../../../../data/models/match_history.dart';
import '../../../../data/models/measurement_system.dart';
import '../../../../data/repositories/match_history_repository.dart';
import '../../../../shared/widgets/media/safe_dish_image.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../logic/match_history_provider.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return _DetailScaffold(
      title: 'Edit Profile',
      children: <Widget>[
        _ActionCard(
          children: <Widget>[
            _DetailRow(
              icon: Icons.person_outline,
              title: 'Name',
              value: user?.displayName ?? 'Name',
              onTap: () =>
                  _notice(context, 'Name editing will be available soon.'),
            ),
            _DetailRow(
              icon: Icons.email_outlined,
              title: 'Email',
              value: user?.email ?? '',
              onTap: () => _showInfo(
                context,
                'Change Email',
                'Email changes may require confirmation. This feature will be available soon.',
              ),
            ),
            _DetailRow(
              icon: Icons.lock_outline,
              title: 'Password',
              onTap: () => _showInfo(
                context,
                'Change Password',
                'Password change will be available soon.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class MatchHistoryScreen extends StatelessWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MatchHistoryProvider>(
      create: (_) => MatchHistoryProvider(
        repository: context.read<MatchHistoryRepository>(),
      )..load(),
      child: const MatchHistoryContent(),
    );
  }
}

/// Presentational match-history content separated from repository loading so
/// it can be hosted with an existing provider in focused widget tests.
class MatchHistoryContent extends StatelessWidget {
  const MatchHistoryContent({super.key});

  @override
  Widget build(BuildContext context) {
    final MatchHistoryProvider provider = context.watch<MatchHistoryProvider>();
    if (provider.isLoading) {
      return const _DetailScaffold(
        title: 'Match History',
        children: <Widget>[Center(child: CircularProgressIndicator())],
      );
    }
    if (provider.error != null) {
      return _DetailScaffold(
        title: 'Match History',
        children: <Widget>[
          const SizedBox(height: 80),
          Center(child: Text(context.copy.error(provider.error!))),
          Center(
            child: TextButton(
              onPressed: provider.load,
              child: Text(context.tr('Try Again')),
            ),
          ),
        ],
      );
    }
    final MatchHistory history = provider.history;
    if (history.solo.isEmpty && history.pair.isEmpty) {
      return const _DetailScaffold(
        title: 'Match History',
        children: <Widget>[_MatchHistoryEmptyState()],
      );
    }
    return _DetailScaffold(
      title: 'Match History',
      children: <Widget>[
        const _Header('Solo'),
        if (history.solo.isEmpty)
          const _EmptyModeCard('No solo matches yet')
        else
          for (final MatchHistorySession session in history.solo)
            _HistorySessionCard(session: session),
        const _Header('Pair'),
        if (history.pair.isEmpty)
          const _EmptyModeCard('No pair matches yet')
        else
          for (final MatchHistorySession session in history.pair)
            _HistorySessionCard(session: session),
      ],
    );
  }
}

class MatchHistorySessionScreen extends StatefulWidget {
  const MatchHistorySessionScreen({
    required this.sessionId,
    this.initialSession,
    super.key,
  });
  final String sessionId;
  final MatchHistorySession? initialSession;

  @override
  State<MatchHistorySessionScreen> createState() =>
      _MatchHistorySessionScreenState();
}

class _MatchHistorySessionScreenState extends State<MatchHistorySessionScreen> {
  MatchHistorySession? _session;
  bool _isLoading = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    _load();
  }

  Future<void> _load() async {
    final int generation = ++_requestGeneration;
    setState(() => _isLoading = true);
    try {
      final MatchHistorySession? session = await context
          .read<MatchHistoryRepository>()
          .getSession(widget.sessionId);
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _session = session);
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _session = null);
    } finally {
      if (mounted && generation == _requestGeneration)
        setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant MatchHistorySessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId == widget.sessionId) return;
    _requestGeneration++;
    _session = widget.initialSession;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _DetailScaffold(
        title: 'Match History',
        children: <Widget>[Center(child: CircularProgressIndicator())],
      );
    }
    final MatchHistorySession? session = _session;
    if (session == null) {
      return _DetailScaffold(
        title: 'Session not found',
        children: <Widget>[
          SizedBox(height: 80),
          Center(
            child: Text(
              context.tr('This match history session is no longer available.'),
            ),
          ),
        ],
      );
    }
    return _DetailScaffold(
      title: session.mode == MatchHistoryMode.solo
          ? 'Solo Session'
          : 'Pair Session',
      children: <Widget>[
        _ActionCard(
          children: <Widget>[
            for (final dish in session.dishes)
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SafeDishImage(
                    imageUrl: dish.imageUrl,
                    fit: BoxFit.cover,
                    width: 52,
                    height: 52,
                  ),
                ),
                title: Text(dish.name),
                subtitle: Text(
                  context.tr(
                    session.mode == MatchHistoryMode.solo
                        ? 'Liked dish'
                        : 'Mutual match',
                  ),
                ),
                onTap: () =>
                    context.push('/recipe-detail/${dish.id}', extra: dish),
              ),
          ],
        ),
      ],
    );
  }
}

class _MatchHistoryEmptyState extends StatelessWidget {
  const _MatchHistoryEmptyState();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 72),
    child: Column(
      children: <Widget>[
        const FoodMatchEmptyStateImage(
          assetPath: AppEmptyStateAssets.emptyMatchHistory,
          size: 180,
          fallback: FoodMatchEmptyStateImage(
            assetPath: AppEmptyStateAssets.emptyMatches,
            size: 180,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('No matches yet'),
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('Your matched dishes will appear here.'),
          style: TextStyle(color: context.fmColors.textMuted),
        ),
      ],
    ),
  );
}

class _EmptyModeCard extends StatelessWidget {
  const _EmptyModeCard(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => _ActionCard(
    children: <Widget>[
      ListTile(
        leading: const Icon(Icons.history_rounded),
        title: Text(context.tr(message)),
      ),
    ],
  );
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({required this.session});
  final MatchHistorySession session;

  @override
  Widget build(BuildContext context) {
    final String names = session.previewDishes
        .take(3)
        .map((dish) => dish.name)
        .join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ActionCard(
        children: <Widget>[
          ListTile(
            title: Text(
              session.mode == MatchHistoryMode.pair
                  ? (session.partnerName?.trim().isNotEmpty == true
                        ? session.partnerName!
                        : context.tr('Pair session'))
                  : context.tr('Solo session'),
            ),
            subtitle: Text(
              '${_formatDate(context, session.startedAt)} • ${context.copy.count(session.mode == MatchHistoryMode.solo ? 'likes' : 'matches', session.dishCount)}${names.isEmpty ? '' : '\n$names'}',
            ),
            isThreeLine: names.isNotEmpty,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(
              '/profile/match-history/session/${session.sessionId}',
              extra: session,
            ),
          ),
          if (session.previewDishes.isNotEmpty)
            InkWell(
              onTap: () => context.push(
                '/profile/match-history/session/${session.sessionId}',
                extra: session,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: <Widget>[
                    for (final dish in session.previewDishes.take(
                      3,
                    )) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SafeDishImage(
                          imageUrl: dish.imageUrl,
                          fit: BoxFit.cover,
                          width: 48,
                          height: 48,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: 'Settings',
    children: <Widget>[
      const _Header('Subscription'),
      _ActionCard(
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.workspace_premium_outlined),
            title: Text(context.tr('Premium subscription')),
            subtitle: Text(
              context.tr('See your plan and available subscription options.'),
            ),
            onTap: () => context.push('/profile/premium'),
          ),
        ],
      ),
      const _Header('Notifications'),
      _ActionCard(
        children: <Widget>[
          SwitchListTile(
            value: false,
            onChanged: null,
            secondary: Icon(Icons.notifications_outlined),
            title: Text(context.tr('Push Notifications')),
            subtitle: Text(
              context.tr('Notification controls are coming soon.'),
            ),
          ),
        ],
      ),
      const _Header('General'),
      _ActionCard(
        children: <Widget>[
          _DetailRow(
            icon: Icons.language_rounded,
            title: 'Language',
            value: _languageLabel(context),
            onTap: () => _showLanguage(context),
          ),
          _DetailRow(
            icon: Icons.straighten_outlined,
            title: 'Units',
            value: context.tr(
              context.watch<AuthProvider>().measurementSystemPreference.label,
            ),
            onTap: () => _showUnits(context),
          ),
          _DetailRow(
            icon: Icons.palette_outlined,
            title: 'Color Theme',
            value: context.tr(
              _themeLabel(context.watch<ThemeController>().themeMode),
            ),
            onTap: () => _showTheme(context),
          ),
        ],
      ),
      const _Header('Privacy & Data'),
      _ActionCard(
        children: <Widget>[
          _DetailRow(
            icon: Icons.download_outlined,
            title: 'Export Data',
            onTap: () =>
                _notice(context, 'Data export will be available soon.'),
          ),
          _DetailRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Consent Management',
            onTap: () =>
                _notice(context, 'Consent management will be available soon.'),
          ),
        ],
      ),
      const _Header('Account'),
      _ActionCard(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: Text(
              context.tr('Delete Account'),
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    ],
  );

  String _languageLabel(BuildContext context) {
    final code = context.watch<LocaleController>().locale?.languageCode;
    return switch (code) {
      'en' => 'English',
      'de' => 'Deutsch',
      _ => context.tr('System default'),
    };
  }

  Future<void> _showLanguage(BuildContext context) async {
    final controller = context.read<LocaleController>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(sheetContext.tr('Language'))),
            for (final locale in <Locale?>[
              null,
              ...LocaleController.supportedLocales,
            ])
              ListTile(
                title: Text(
                  locale == null
                      ? sheetContext.tr('System default')
                      : locale.languageCode == 'de'
                      ? 'Deutsch'
                      : 'English',
                ),
                trailing: controller.locale == locale
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  try {
                    await controller.setLocale(locale);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } catch (_) {
                    if (!sheetContext.mounted) return;
                    FoodMatchNotifications.show(
                      sheetContext,
                      type: FoodMatchNotificationType.error,
                      title: 'Could not save language. Please try again.',
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUnits(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final value = auth.measurementSystemPreference;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<MeasurementSystemPreference>(
          groupValue: value,
          onChanged: (selected) async {
            if (selected == null) return;
            final success = await auth.updateMeasurementSystemPreference(
              selected,
            );
            if (!sheetContext.mounted) return;
            if (success) {
              Navigator.pop(sheetContext);
            } else {
              FoodMatchNotifications.show(
                sheetContext,
                type: FoodMatchNotificationType.error,
                title: 'Could not update units. Please try again.',
              );
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text(
                  context.tr('Units'),
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              for (final option in MeasurementSystemPreference.values)
                RadioListTile<MeasurementSystemPreference>(
                  value: option,
                  title: Text(context.tr(option.label)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTheme(BuildContext context) async {
    final controller = context.read<ThemeController>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(
                context.tr('Color Theme'),
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final option in ThemeMode.values)
              ListTile(
                title: Text(context.tr(_themeLabel(option))),
                trailing: controller.themeMode == option
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  await controller.setThemeMode(option);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Delete Account?')),
        content: Text(
          context.tr(
            'This action would permanently delete your account and data.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.tr('Delete Account'),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted)
      _notice(context, 'Account deletion is not available yet.');
  }
}

class AboutFoodMatchScreen extends StatelessWidget {
  const AboutFoodMatchScreen({super.key});
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: 'About FoodMatch',
    children: <Widget>[
      _ActionCard(
        children: <Widget>[
          const _DetailRow(
            icon: Icons.info_outline,
            title: 'Version',
            value: '0.1.0',
          ),
          _DetailRow(
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            onTap: () =>
                _notice(context, 'Privacy Policy will be available soon.'),
          ),
          _DetailRow(
            icon: Icons.description_outlined,
            title: 'Terms of Use',
            onTap: () =>
                _notice(context, 'Terms of Use will be available soon.'),
          ),
        ],
      ),
    ],
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: 'Help',
    children: <Widget>[
      _ActionCard(
        children: <Widget>[
          _DetailRow(
            icon: Icons.mail_outline,
            title: 'Contact Us',
            onTap: () =>
                _notice(context, 'Support contact will be available soon.'),
          ),
          _DetailRow(
            icon: Icons.star_outline,
            title: 'Rate Us',
            onTap: () =>
                _notice(context, 'Rating will be available after release.'),
          ),
          _DetailRow(
            icon: Icons.share_outlined,
            title: 'Share App',
            onTap: () => _notice(
              context,
              'App sharing will be available after release.',
            ),
          ),
        ],
      ),
    ],
  );
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.fmColors.background,
    appBar: AppBar(
      backgroundColor: context.fmColors.background,
      title: Text(
        context.tr(title),
        style: AppTextStyles.pageTitle.copyWith(
          fontSize: 30,
          color: context.fmColors.textPrimary,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: children,
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      context.tr(text),
      style: GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: context.fmColors.textMuted,
      ),
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: context.fmColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: context.fmColors.border),
    ),
    child: Column(children: children),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(context.tr(title)),
    subtitle: value == null ? null : Text(value!),
    trailing: onTap == null && value != null
        ? null
        : const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

String _themeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.system => 'System',
  ThemeMode.light => 'Light theme',
  ThemeMode.dark => 'Dark',
};

void _notice(BuildContext context, String message) =>
    FoodMatchNotifications.show(
      context,
      type: FoodMatchNotificationType.info,
      title: message,
    );

Future<void> _showInfo(BuildContext context, String title, String message) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr(title)),
        content: Text(context.tr(message)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('OK')),
          ),
        ],
      ),
    );
