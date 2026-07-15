import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/couple_invitation.dart';
import '../../../../shared/widgets/media/safe_avatar_image.dart';

class ContinuationInvitationSheet extends StatelessWidget {
  const ContinuationInvitationSheet({
    super.key,
    required this.invitation,
    required this.onJoin,
    required this.onDecline,
  });

  final CoupleInvitation invitation;
  final VoidCallback onJoin;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final String name = invitation.fromUser.displayName.trim().isEmpty ? 'Partner' : invitation.fromUser.displayName.trim();
    final int? matchCount = invitation.mutualMatchCount;
    return SafeArea(
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
              decoration: BoxDecoration(color: colors.textMuted, borderRadius: BorderRadius.circular(99)),
            ),
            const SizedBox(height: 34),
            Row(
              children: <Widget>[
                SafeAvatarImage(imageUrl: invitation.fromUser.avatarUrl, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$name invited you',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(fontSize: 13, color: colors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Continue last session',
                        style: GoogleFonts.nunito(fontSize: 16, color: colors.textPrimary, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: colors.primarySoft, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    'Pair mode',
                    style: GoogleFonts.nunito(fontSize: 11, color: colors.primary, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: colors.cardElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.primary, width: 2)),
                    child: Icon(Icons.favorite_border_rounded, color: colors.primary, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.nunito(fontSize: 14, color: colors.textSecondary, height: 1.3),
                        children: <TextSpan>[
                          if (matchCount == null)
                            TextSpan(
                              text: 'Ready to continue your last session?',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: colors.textPrimary),
                            )
                          else ...<TextSpan>[
                            const TextSpan(text: 'You had '),
                            TextSpan(
                              text: _matchCountLabel(matchCount),
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: colors.textPrimary),
                            ),
                            TextSpan(
                              text: matchCount == 0 ? ' together last time. Ready to try again?' : ' together last time. Ready for more?',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 46),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.buttonPrimaryBackground,
                  foregroundColor: colors.buttonPrimaryText,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                  textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                child: const Text('Join session'),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDecline,
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.card,
                  foregroundColor: colors.textMuted,
                  side: BorderSide(color: colors.border, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                  textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                child: const Text('Decline'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


String _matchCountLabel(int count) {
  if (count == 0) return 'no matches';
  if (count == 1) return '1 match';
  return '$count matches';
}
