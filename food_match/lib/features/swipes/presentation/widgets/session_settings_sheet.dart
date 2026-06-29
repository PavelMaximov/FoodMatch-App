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
        color: Color(0xFFFFFBF9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 22,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SheetHeader(onClose: () => Navigator.pop(context)),
              const SizedBox(height: 22),
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

    await context.read<SwipeProvider>().abandonActiveSoloSession();
    if (!context.mounted) return;
    final MatchProvider matchProvider = context.read<MatchProvider>();
    matchProvider.setMode('paired');
    matchProvider.clearMatches();
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
    final MatchProvider matchProvider = context.read<MatchProvider>();
    matchProvider.setSoloSession(null);
    matchProvider.clearMatches();
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
          builder: (BuildContext dialogContext) => AlertDialog(
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
          ),
        ) ??
        false;
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            'Session information',
            style: GoogleFonts.fredoka(
              fontSize: 31,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: Colors.black,
            ),
          ),
        ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, size: 26, color: Color(0xFF2B2725)),
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
        const _SimpleInfoCard(
          icon: Icons.info_outline,
          text: 'You’re currently in solo mode',
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(child: _StatTile(label: 'Liked', value: likedCount.toString())),
            const SizedBox(width: 12),
            Expanded(child: _StatTile(label: 'Remaining', value: remainingCount.toString())),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'You can switch to a Pair session.',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7A7270),
          ),
        ),
        const SizedBox(height: 10),
        _SwitchModeCard(
          icon: Icons.group_rounded,
          title: 'Pair up',
          badge: '2 people',
          subtitle: 'Swipe together with a partner in real time.',
          buttonText: 'Switch to Pair',
          onPressed: onSwitch,
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
      fallback: coupleProvider.hasPartner ? 'Partner connected' : 'Waiting...',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Invite code:',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      inviteCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 32,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _CopyPill(inviteCode: inviteCode),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Partner: $partnerLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: const Color(0xFF8B8582),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: coupleProvider.isLoading ? null : coupleProvider.resetCouple,
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: coupleProvider.isLeaving ? null : coupleProvider.leaveCouple,
                      child: const Text('Leave'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'You can switch to a Solo session.',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7A7270),
          ),
        ),
        const SizedBox(height: 10),
        _SwitchModeCard(
          icon: Icons.person_rounded,
          title: 'Solo',
          subtitle: 'Swipe through dishes just for yourself.',
          buttonText: 'Switch to Solo',
          onPressed: onSwitch,
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
        const _SimpleInfoCard(
          icon: Icons.info_outline,
          text: 'No active swipe session.',
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

class _SimpleInfoCard extends StatelessWidget {
  const _SimpleInfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: const Color(0xFF7A7270)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchModeCard extends StatelessWidget {
  const _SwitchModeCard({
    required this.icon,
    required this.title,
    this.badge,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String? badge;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
                    Row(
                      children: <Widget>[
                        Text(
                          title,
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (badge != null) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDDE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge!,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFEE8C04),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: const Color(0xFF7A7270),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyPill extends StatelessWidget {
  const _CopyPill({required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: inviteCode.isEmpty
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: inviteCode));
              SnackBarUtils.showSuccess(context, 'Code copied!');
            },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.copy, size: 14, color: AppColors.textSecondary.withValues(alpha: 0.72)),
            const SizedBox(width: 4),
            Text(
              'Copy',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7A7270),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
