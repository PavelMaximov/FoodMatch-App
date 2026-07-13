import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/couple.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../matches/logic/match_provider.dart';
import '../../logic/pre_swipe_provider.dart';
import '../../logic/swipe_provider.dart';

class PairConnectionStepScreen extends StatefulWidget {
  const PairConnectionStepScreen({
    super.key,
    required this.onBack,
    required this.onPairConnected,
  });

  final VoidCallback onBack;
  final Future<void> Function() onPairConnected;

  @override
  State<PairConnectionStepScreen> createState() => _PairConnectionStepScreenState();
}

class _PairConnectionStepScreenState extends State<PairConnectionStepScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  bool _isJoining = false;
  bool _handledConnectedSession = false;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  String get _code => _sanitizeCode(_codeController.text);

  Future<void> _createSession(CoupleProvider provider) async {
    await provider.createCouple();
    provider.startFilterStatePolling(reason: 'pair_connection_step_create');
    if (!mounted) return;
    context.read<SwipeProvider>().clearPreparedDeck();
    final MatchProvider matchProvider = context.read<MatchProvider>();
    matchProvider.setMode('paired');
    matchProvider.clearMatches();
  }

  Future<void> _joinSession(CoupleProvider provider) async {
    final String code = _code;
    if (code.length != 6 || _isJoining) return;
    setState(() => _isJoining = true);
    try {
      await provider.joinCouple(code, replaceEmptyCurrentSession: true);
      if (!mounted || provider.error != null) return;
      provider.startFilterStatePolling(reason: 'pair_connection_step_join');
      context.read<SwipeProvider>().clearPreparedDeck();
      context.read<MatchProvider>().setMode('paired');
      context.read<MatchProvider>().clearMatches();
      if (provider.hasPartner) {
        _handledConnectedSession = true;
        await widget.onPairConnected();
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _pasteCode() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String pasted = _sanitizeCode(data?.text ?? '');
    if (pasted.isEmpty) return;
    _codeController.text = pasted.substring(0, pasted.length > 6 ? 6 : pasted.length);
  }

  Future<void> _resetSession(CoupleProvider provider) async {
    await provider.resetCouple();
    if (!mounted) return;
    context.read<SwipeProvider>().clearPreparedDeck();
    context.read<PreSwipeProvider>().clearDraft();
    context.read<MatchProvider>().clearMatches();
  }

  Future<void> _leaveSession(CoupleProvider provider) async {
    await provider.leaveCouple();
    if (!mounted) return;
    context.read<SwipeProvider>().clearPreparedDeck();
    context.read<PreSwipeProvider>().clearDraft();
    context.read<MatchProvider>().clearMatches();
  }


  Future<void> _handleBack(CoupleProvider provider) async {
    final bool hasSession = provider.currentCouple != null && provider.currentCouple!.inviteCode.trim().isNotEmpty;
    if (!hasSession) {
      widget.onBack();
      return;
    }
    final bool leave = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: context.fmColors.modalBackground,
            title: Text('Leave pair setup?', style: TextStyle(color: context.fmColors.textPrimary)),
            content: Text('Your current invite code will be closed.', style: TextStyle(color: context.fmColors.textSecondary)),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('Cancel', style: TextStyle(color: context.fmColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        ) ??
        false;
    if (!leave || !mounted) {
      return;
    }
    await _leaveSession(provider);
    if (mounted) {
      widget.onBack();
    }
  }

  String _partnerLabel(BuildContext context, CoupleProvider provider) {
    return resolvePartnerDisplayName(
      couple: provider.currentCouple,
      currentUserId: context.read<AuthProvider>().currentUser?.id,
      fallback: 'Connected',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CoupleProvider>(
      builder: (BuildContext context, CoupleProvider coupleProvider, _) {
        final FoodMatchThemeColors colors = context.fmColors;
        final Couple? couple = coupleProvider.currentCouple;
        final bool hasSession = couple != null && couple.inviteCode.trim().isNotEmpty;
        if (hasSession && coupleProvider.hasPartner && !_handledConnectedSession) {
          _handledConnectedSession = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onPairConnected();
            }
          });
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => _handleBack(coupleProvider),
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Create session',
                    style: GoogleFonts.fredoka(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (hasSession) ...<Widget>[
                _InviteCard(
                  inviteCode: couple.inviteCode,
                  partnerLabel: _partnerLabel(context, coupleProvider),
                  hasPartner: coupleProvider.hasPartner,
                  onReset: coupleProvider.isLoading ? null : () => _resetSession(coupleProvider),
                  onLeave: coupleProvider.isLoading ? null : () => _handleBack(coupleProvider),
                ),
                const SizedBox(height: 26),
              ] else ...<Widget>[
                Text(
                  'Create your own session',
                  style: _sectionTitleStyle(context),
                ),
                const SizedBox(height: 12),
                _OrangeButton(
                  label: '+ Create session',
                  isLoading: coupleProvider.isLoading,
                  onPressed: coupleProvider.isLoading ? null : () => _createSession(coupleProvider),
                ),
                const SizedBox(height: 30),
              ],
              Text(
                'Join an existing session',
                style: _sectionTitleStyle(context),
              ),
                const SizedBox(height: 14),
                _CodeInput(
                  code: _code,
                  focusNode: _codeFocusNode,
                  controller: _codeController,
                  onPaste: _pasteCode,
                ),
                const SizedBox(height: 16),
                _OrangeButton(
                  label: 'Connect to session',
                  isLoading: _isJoining || coupleProvider.isJoining,
                  onPressed: _code.length == 6 ? () => _joinSession(coupleProvider) : null,
                ),
              if (coupleProvider.error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  coupleProvider.error!,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: coupleProvider.hasActiveSessionConflict ? colors.textSecondary : colors.error,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  TextStyle _sectionTitleStyle(BuildContext context) => GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: context.fmColors.textPrimary,
      );
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.inviteCode,
    required this.partnerLabel,
    required this.hasPartner,
    required this.onReset,
    required this.onLeave,
  });

  final String inviteCode;
  final String partnerLabel;
  final bool hasPartner;
  final VoidCallback? onReset;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Invite code:', style: GoogleFonts.nunito(fontSize: 14, color: colors.textSecondary)),
                    const SizedBox(height: 4),
                    SelectableText(inviteCode, style: GoogleFonts.nunito(fontSize: 34, fontWeight: FontWeight.w800, color: colors.textPrimary, letterSpacing: 2)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: inviteCode));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text('Partner:', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary)),
              const SizedBox(width: 4),
              if (hasPartner)
                Flexible(
                  child: Text(
                    partnerLabel,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                )
              else
                Lottie.asset(
                  'assets/animations/loading_3_dots.json',
                  width: 32,
                  height: 18,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
            ],
          ),
          if (hasPartner) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.buttonSecondaryBackground,
                    foregroundColor: colors.buttonSecondaryText,
                    side: BorderSide(color: colors.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onLeave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.buttonPrimaryBackground,
                    foregroundColor: colors.buttonPrimaryText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                  ),
                  child: const Text('Leave'),
                ),
              ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.code,
    required this.focusNode,
    required this.controller,
    required this.onPaste,
  });

  final String code;
  final FocusNode focusNode;
  final TextEditingController controller;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return GestureDetector(
      onTap: focusNode.requestFocus,
      child: Stack(
        children: <Widget>[
          Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: 6,
              keyboardType: TextInputType.text,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(6),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              for (int i = 0; i < 6; i += 1) ...<Widget>[
                Expanded(
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.inputBorder),
                    ),
                    child: Text(
                      i < code.length ? code[i] : '0',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: i < code.length ? colors.textPrimary : colors.textMuted,
                      ),
                    ),
                  ),
                ),
                if (i != 5) const SizedBox(width: 7),
              ],
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste_rounded, size: 15),
                label: const Text('paste'),
              ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OrangeButton extends StatelessWidget {
  const _OrangeButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.fmColors.buttonPrimaryBackground,
          disabledBackgroundColor: context.fmColors.buttonPrimaryBackground.withValues(alpha: 0.55),
          foregroundColor: context.fmColors.buttonPrimaryText,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
        ),
        child: isLoading
            ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: context.fmColors.buttonPrimaryText))
            : Text(label, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

String _sanitizeCode(String value) => value.replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
