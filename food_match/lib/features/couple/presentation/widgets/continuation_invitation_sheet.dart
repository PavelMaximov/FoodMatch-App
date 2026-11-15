import 'package:food_match/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/couple_invitation.dart';
import '../../../../shared/widgets/media/safe_avatar_image.dart';

class ContinuationInvitationSheet extends StatefulWidget {
  const ContinuationInvitationSheet({
    super.key,
    required this.invitation,
    required this.onJoin,
    required this.onDecline,
  });

  final CoupleInvitation invitation;
  final Future<void> Function() onJoin;
  final Future<void> Function() onDecline;

  @override
  State<ContinuationInvitationSheet> createState() =>
      _ContinuationInvitationSheetState();
}

class _ContinuationInvitationSheetState
    extends State<ContinuationInvitationSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'Could not update the invitation. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.invitation;
    final FoodMatchThemeColors colors = context.fmColors;
    final String name = invitation.fromUser.displayName.trim().isEmpty
        ? context.tr('Partner')
        : invitation.fromUser.displayName.trim();
    final int? matchCount = invitation.mutualMatchCount;
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 39,
                height: 2,
                decoration: BoxDecoration(
                  color: colors.textMuted,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 34),
              Row(
                children: <Widget>[
                  SafeAvatarImage(
                    imageUrl: invitation.fromUser.avatarUrl,
                    size: 44,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.tr('{name} invited you', {'name': name}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('Continue last session'),
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      context.tr('Pair mode'),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: colors.cardElevated,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.primary, width: 2),
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        color: colors.primary,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            color: colors.textSecondary,
                            height: 1.3,
                          ),
                          children: <TextSpan>[
                            if (matchCount == null)
                              TextSpan(
                                text: context.tr(
                                  'Ready to continue your last session?',
                                ),
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w900,
                                  color: colors.textPrimary,
                                ),
                              )
                            else
                              TextSpan(
                                text: context.tr('invitation.summary', {
                                  'matches': context.copy.count(
                                    'matches',
                                    matchCount,
                                  ),
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  context.copy.error(_error!),
                  key: const Key('invitation-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 46),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _run(widget.onJoin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.buttonPrimaryBackground,
                    foregroundColor: colors.buttonPrimaryText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                    ),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(
                    context.tr(_busy ? 'Please wait...' : 'Join session'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _run(widget.onDecline),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.card,
                    foregroundColor: colors.textMuted,
                    side: BorderSide(color: colors.border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                    ),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(context.tr('Decline')),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(context.tr('Not now')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
