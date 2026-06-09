import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../data/models/couple.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../matches/logic/match_provider.dart';
import '../../../swipes/logic/pre_swipe_provider.dart';
import '../../../swipes/logic/swipe_provider.dart';
import '../../logic/couple_provider.dart';

class ConnectSessionSheet extends StatefulWidget {
  const ConnectSessionSheet({super.key});

  @override
  State<ConnectSessionSheet> createState() => _ConnectSessionSheetState();
}

class _ConnectSessionSheetState extends State<ConnectSessionSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _hasLoadedCurrentSession = false;
  bool _leaveRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentSession());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSession() async {
    if (!mounted || _hasLoadedCurrentSession) return;
    _hasLoadedCurrentSession = true;

    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    if (coupleProvider.hasCouple || coupleProvider.isLoading) return;

    await coupleProvider.loadCouple();
    if (!mounted) return;
    if (coupleProvider.error != null) {
      SnackBarUtils.showError(context, coupleProvider.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Consumer<CoupleProvider>(
            builder: (BuildContext context, CoupleProvider coupleProvider, _) {
              final Couple? couple = coupleProvider.currentCouple;
              final bool hasRealCouple = couple != null && couple.inviteCode.trim().isNotEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _SheetHeader(onClose: () => Navigator.pop(context)),
                  const SizedBox(height: 34),
                  if (hasRealCouple) ...<Widget>[
                    _InviteCodePanel(
                      inviteCode: couple.inviteCode,
                      partnerLabel: _partnerLabel(context, coupleProvider),
                      isLoading: false,
                    ),
                    const SizedBox(height: 24),
                    _buildActiveSessionControls(coupleProvider),
                  ] else ...<Widget>[
                    _buildNoSessionControls(coupleProvider),
                    const SizedBox(height: 24),
                    _buildJoinControls(coupleProvider),
                  ],
                  if (coupleProvider.error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      coupleProvider.error!,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: coupleProvider.hasActiveSessionConflict ? AppColors.textSecondary : AppColors.error,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }



  Widget _buildNoSessionControls(CoupleProvider coupleProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Create your own session',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start a new invite code or join one from your partner below.',
          style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: coupleProvider.isLoading ? null : () => _createSession(coupleProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: coupleProvider.isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    'Create session',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionControls(CoupleProvider coupleProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'You already have an active session. Leave it before joining another one.',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: coupleProvider.isLoading || coupleProvider.isLeaving || _leaveRequestInFlight
                    ? null
                    : () => _leaveSession(coupleProvider),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Leave session'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: coupleProvider.isLoading ? null : coupleProvider.resetCouple,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reset'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinControls(CoupleProvider coupleProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Join an existing session',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter the invitation code',
            hintStyle: GoogleFonts.nunito(
              fontSize: 14,
              color: AppColors.textHint,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: coupleProvider.isLoading || coupleProvider.isJoining
                ? null
                : () => _connectToSession(coupleProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: coupleProvider.isLoading || coupleProvider.isJoining
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Connect to session',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }


  Future<void> _createSession(CoupleProvider coupleProvider) async {
    await coupleProvider.createCouple();
    if (!mounted) return;
    if (coupleProvider.error != null) {
      SnackBarUtils.showError(context, coupleProvider.error!);
    }
  }

  Future<void> _leaveSession(CoupleProvider coupleProvider) async {
    if (_leaveRequestInFlight) {
      return;
    }
    setState(() => _leaveRequestInFlight = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await coupleProvider.leaveCouple();
    if (!mounted) return;
    setState(() => _leaveRequestInFlight = false);
    if (coupleProvider.error != null) {
      SnackBarUtils.showError(context, coupleProvider.error!);
      return;
    }
    context.read<SwipeProvider>().clearPreparedDeck();
    context.read<PreSwipeProvider>().clearForLogout();
    context.read<MatchProvider>().clearMatches();
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Session left'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _connectToSession(CoupleProvider coupleProvider) async {
    if (coupleProvider.hasCouple) {
      SnackBarUtils.showError(context, 'You already have an active session. Leave it before joining another one.');
      return;
    }

    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      SnackBarUtils.showError(context, 'Enter the invitation code');
      return;
    }

    await coupleProvider.joinCouple(code);
    if (!mounted) return;
    if (coupleProvider.hasActiveSessionConflict) {
      SnackBarUtils.showError(context, CoupleProvider.activeSessionMessage);
      return;
    }
    if (coupleProvider.currentCouple != null) {
      Navigator.pop(context);
      SnackBarUtils.showSuccess(context, 'Connected to session!');
    } else if (coupleProvider.error != null) {
      SnackBarUtils.showError(context, coupleProvider.error!);
    }
  }

  String _partnerLabel(BuildContext context, CoupleProvider coupleProvider) {
    final String? currentUserId = context.read<AuthProvider>().currentUser?.id;
    return resolvePartnerDisplayName(
      couple: coupleProvider.currentCouple,
      currentUserId: currentUserId,
      fallback: 'Partner connected',
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.link, size: 34, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Text(
                'Create a session',
                style: GoogleFonts.fredoka(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: -4,
          top: -6,
          child: IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close, size: 28, color: AppColors.textSecondary.withValues(alpha: 0.78)),
            splashRadius: 22,
          ),
        ),
      ],
    );
  }
}

class _InviteCodePanel extends StatelessWidget {
  const _InviteCodePanel({
    required this.inviteCode,
    required this.partnerLabel,
    required this.isLoading,
  });

  final String inviteCode;
  final String partnerLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 18, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Invite code:',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    inviteCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 34,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              _CopyButton(inviteCode: inviteCode),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Partner: $partnerLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: inviteCode));
        SnackBarUtils.showSuccess(context, 'Code copied!');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
