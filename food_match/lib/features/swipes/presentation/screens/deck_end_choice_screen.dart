import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/couple.dart';
import '../../../../data/models/couple_filter_state.dart';
import '../../../../shared/widgets/media/safe_avatar_image.dart';

class DeckEndChoiceScreen extends StatelessWidget {
  const DeckEndChoiceScreen({
    super.key,
    required this.isSoloMode,
    required this.onUsePreviousFilter,
    required this.onStartNew,
    this.partner,
    this.choices = const CoupleFilterChoices(),
  });

  final bool isSoloMode;
  final VoidCallback onUsePreviousFilter;
  final VoidCallback onStartNew;
  final CoupleMemberProfile? partner;
  final CoupleFilterChoices choices;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final String partnerName = _partnerName(partner);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Image.asset(
              'assets/media/pre_swipe_intro.png',
              height: 190,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Session complete',
            style: GoogleFonts.fredoka(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Would you like to continue with previous setup or start a new session?',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 15,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onUsePreviousFilter,
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.background,
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: const Text('Continue as before'),
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onStartNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.buttonPrimaryBackground,
                foregroundColor: colors.buttonPrimaryText,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: const Text('Create a new session'),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  isSoloMode ? 'Solo' : 'With $partnerName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
              ),
              if (!isSoloMode) _PartnerAvatar(partner: partner, partnerName: partnerName),
            ],
          ),
          const SizedBox(height: 12),
          _FilterSummaryCard(choices: choices),
        ],
      ),
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({required this.partner, required this.partnerName});

  final CoupleMemberProfile? partner;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final String? avatarUrl = partner?.avatarUrl;
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      return ClipOval(child: SafeAvatarImage(imageUrl: avatarUrl, size: 24));
    }
    final FoodMatchThemeColors colors = context.fmColors;
    return CircleAvatar(
      radius: 12,
      backgroundColor: colors.primarySoft,
      child: Text(
        partnerName.isEmpty ? '?' : partnerName.substring(0, 1).toUpperCase(),
        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w900, color: colors.primary),
      ),
    );
  }
}

class _FilterSummaryCard extends StatelessWidget {
  const _FilterSummaryCard({required this.choices});

  final CoupleFilterChoices choices;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: <Widget>[
          _FilterSection(icon: Icons.room_service_outlined, label: 'Cuisine:', values: choices.cuisines),
          Divider(height: 1, color: colors.divider),
          _FilterSection(icon: Icons.auto_awesome, label: 'Mood:', values: choices.moods),
          Divider(height: 1, color: colors.divider),
          _FilterSection(icon: Icons.do_not_disturb_alt_outlined, label: 'Exceptions:', values: choices.exclusions),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.icon, required this.label, required this.values});

  final IconData icon;
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final List<String> chips = values.isEmpty ? <String>['None'] : values;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: colors.primary, size: 21),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.nunito(fontSize: 15, color: colors.textMuted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chips
                .map(
                  (String value) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.chipBackground,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: colors.chipBorder),
                    ),
                    child: Text(
                      values.isEmpty ? value : _formatOptionLabel(value),
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

String _partnerName(CoupleMemberProfile? partner) {
  final String? email = partner?.email;
  final String? emailPrefix = email == null || !email.contains('@') ? email : email.split('@').first;
  final List<String?> candidates = <String?>[partner?.displayName, partner?.name, partner?.username, emailPrefix];
  for (final String? candidate in candidates) {
    final String value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return 'your partner';
}

String _formatOptionLabel(String value) => value
    .trim()
    .replaceAll('_', ' ')
    .split(RegExp(r'\s+'))
    .where((String word) => word.isNotEmpty)
    .map((String word) => word[0].toUpperCase() + word.substring(1))
    .join(' ');
