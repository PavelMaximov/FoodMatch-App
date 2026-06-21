import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/couple.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../matches/logic/match_provider.dart';
import '../../logic/pre_swipe_provider.dart';
import '../../logic/swipe_provider.dart';

class SessionSettingsSheet extends StatelessWidget {
  const SessionSettingsSheet({
    super.key,
    required this.onOpenPairSetup,
    required this.onStartSoloSetup,
  });

  final VoidCallback onOpenPairSetup;
  final VoidCallback onStartSoloSetup;

  @override
  Widget build(BuildContext context) {
    final SwipeProvider swipeProvider = context.watch<SwipeProvider>();
    final CoupleProvider coupleProvider = context.watch<CoupleProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 26,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SheetTitle(onClose: () => Navigator.pop(context)),
              const SizedBox(height: 24),
              if (swipeProvider.isSoloMode)
                _SoloSettings(
                  likedCount: swipeProvider.soloLikedCount,
                  remainingCount: swipeProvider.remainingDishCount,
                  onSwitch: () => _confirmSwitchToPair(context),
                )
              else if (coupleProvider.hasCouple)
                _PairSettings(
                  coupleProvider: coupleProvider,
                  onSwitch: () => _confirmSwitchToSolo(context),
                )
              else
                _NoActiveSession(onPairUp: onOpenPairSetup, onSolo: onStartSoloSetup),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSwitchToPair(BuildContext context) async {
    final bool confirmed = await _confirm(
      context,
      title: 'Switch to Pair up?',
      message: 'This will end your current solo session and open partner setup.',
    );
    if (!confirmed || !context.mounted) return;

    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    await swipeProvider.abandonActiveSoloSession();
    if (!context.mounted) return;
    Navigator.pop(context);
    onOpenPairSetup();
  }

  Future<void> _confirmSwitchToSolo(BuildContext context) async {
    final bool confirmed = await _confirm(
      context,
      title: 'Switch to Solo?',
      message: 'This will leave the current pair session and start solo setup.',
    );
    if (!confirmed || !context.mounted) return;

    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    await coupleProvider.leaveCouple();
    if (!context.mounted) return;
    if (coupleProvider.error != null) {
      SnackBarUtils.showError(context, coupleProvider.error!);
      return;
    }
    context.read<SwipeProvider>().clearPreparedDeck();
    context.read<PreSwipeProvider>().clearForLogout();
    context.read<MatchProvider>().clearMatches();
    Navigator.pop(context);
    onStartSoloSetup();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Switch'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Session settings',
            style: GoogleFonts.fredoka(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: Icon(
            Icons.close,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

class _SoloSettings extends StatelessWidget {
  const _SoloSettings({
    required this.likedCount,
    required this.remainingCount,
    required this.onSwitch,
  });

  final int likedCount;
  final int remainingCount;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _ModeInfoCard(
          mode: 'Solo',
          description:
              'You\'re swiping on your own. Likes are saved to Matches right away.',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(child: _StatTile(label: 'Liked', value: likedCount.toString())),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(label: 'Remaining', value: remainingCount.toString())),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSwitch,
            icon: const Icon(Icons.group_rounded),
            label: const Text('Switch to Pair up'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

class _PairSettings extends StatelessWidget {
  const _PairSettings({required this.coupleProvider, required this.onSwitch});

  final CoupleProvider coupleProvider;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final Couple? couple = coupleProvider.currentCouple;
    final String inviteCode = couple?.inviteCode ?? '';
    final String? currentUserId = context.read<AuthProvider>().currentUser?.id;
    final String partnerLabel = resolvePartnerDisplayName(
      couple: couple,
      currentUserId: currentUserId,
      fallback: coupleProvider.hasPartner ? 'Partner connected' : 'Waiting for partner',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _ModeInfoCard(
          mode: 'Pair up',
          description: 'You\'re in a paired session. Dishes match when both people swipe right.',
          icon: Icons.group_rounded,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7DEDA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Invite code',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      inviteCode,
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: inviteCode.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: inviteCode));
                            SnackBarUtils.showSuccess(context, 'Code copied!');
                          },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Partner: $partnerLabel',
                style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: coupleProvider.isLeaving ? null : coupleProvider.leaveCouple,
                child: const Text('Leave'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: coupleProvider.isLoading ? null : coupleProvider.resetCouple,
                child: const Text('Reset'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSwitch,
            icon: const Icon(Icons.person_rounded),
            label: const Text('Switch to Solo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoActiveSession extends StatelessWidget {
  const _NoActiveSession({required this.onPairUp, required this.onSolo});

  final VoidCallback onPairUp;
  final VoidCallback onSolo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _ModeInfoCard(
          mode: 'No active swipe session',
          description: 'Choose Solo or Pair up to start swiping.',
          icon: Icons.info_outline,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onSolo();
            },
            child: const Text('Start Solo'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              onPairUp();
            },
            child: const Text('Pair up'),
          ),
        ),
      ],
    );
  }
}

class _ModeInfoCard extends StatelessWidget {
  const _ModeInfoCard({
    required this.mode,
    required this.description,
    required this.icon,
  });

  final String mode;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DEDA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDDE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFEE8C04)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Current mode',
                  style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                ),
                Text(
                  mode,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DEDA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
