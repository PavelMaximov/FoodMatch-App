import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/user_profile.dart';

enum PreviousChoicePillType {
  cuisine,
  mood,
  exception,
}

class PreviousFilterChoiceScreen extends StatelessWidget {
  const PreviousFilterChoiceScreen({
    super.key,
    required this.preset,
    required this.onUsePreset,
    required this.onChangeFilters,
    required this.onClose,
  });

  final LastFilterPreset preset;
  final VoidCallback onUsePreset;
  final VoidCallback onChangeFilters;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.history, size: 16, color: colors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastUsedLabel(preset.usedAt),
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Feeling it again\ntoday?',
                style: GoogleFonts.fredoka(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Here\'s what you picked last time.\nJump back in or start fresh.',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  height: 1.35,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              _PresetCard(preset: preset),
              const SizedBox(height: 14),
              _MatchedCard(count: preset.matchedLastTime),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onUsePreset,
                  icon: const Icon(Icons.thumb_up_alt_rounded, size: 20),
                  label: const Text('Yes, same vibe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.buttonPrimaryBackground,
                    foregroundColor: colors.buttonPrimaryText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                    ),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onChangeFilters,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: colors.buttonSecondaryBackground,
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                    ),
                    textStyle: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: const Text('No, let me change filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String lastUsedLabel(DateTime usedAt) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime usedDay = DateTime(usedAt.year, usedAt.month, usedAt.day);
  final int days = today.difference(usedDay).inDays;
  if (days <= 0) return 'Last used today';
  if (days == 1) return 'Last used yesterday';
  if (days < 7) return 'Last used $days days ago';
  if (days < 14) return 'Last used last week';
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Last used on ${months[usedAt.month - 1]} ${usedAt.day}';
}


class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset});

  final LastFilterPreset preset;

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
          _FilterSection(
            icon: Icons.room_service_outlined,
            label: 'Cuisine:',
            values: preset.cuisines,
            type: PreviousChoicePillType.cuisine,
          ),
          Divider(height: 1, color: colors.divider),
          _FilterSection(
            icon: Icons.auto_awesome,
            label: 'Mood:',
            values: preset.moods,
            type: PreviousChoicePillType.mood,
          ),
          Divider(height: 1, color: colors.divider),
          _FilterSection(
            icon: Icons.do_not_disturb_alt_outlined,
            label: 'Exceptions:',
            values: preset.exclusions,
            type: PreviousChoicePillType.exception,
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.icon,
    required this.label,
    required this.values,
    required this.type,
  });

  final IconData icon;
  final String label;
  final List<String> values;
  final PreviousChoicePillType type;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final bool isEmpty = values.isEmpty;
    final List<String> chips = isEmpty ? <String>['None'] : values;
    final _PillColors pillColors = _previousChoicePillColors(context, type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: pillColors.foreground, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: colors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: chips
                .map(
                  (String value) => _PresetChip(
                    label: isEmpty ? value : _formatOptionLabel(value),
                    colors: isEmpty
                        ? _PillColors(
                            background: colors.chipBackground,
                            foreground: colors.textMuted,
                            border: colors.chipBorder,
                          )
                        : pillColors,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

String _formatOptionLabel(String value) {
  final Set<String> uppercaseWords = <String>{'eu', 'uk', 'usa', 'us'};
  return value
      .trim()
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        if (uppercaseWords.contains(lower)) return lower.toUpperCase();
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.colors,
  });

  final String label;
  final _PillColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: colors.foreground,
        ),
      ),
    );
  }
}

class _PillColors {
  const _PillColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

_PillColors _previousChoicePillColors(
  BuildContext context,
  PreviousChoicePillType type,
) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  if (isDark) {
    switch (type) {
      case PreviousChoicePillType.cuisine:
        return const _PillColors(
          background: Color(0xFF4A3218),
          foreground: Color(0xFFF0A03A),
          border: Color(0xFF5A3A1D),
        );
      case PreviousChoicePillType.mood:
        return const _PillColors(
          background: Color(0xFF4A462C),
          foreground: Color(0xFFE2C403),
          border: Color(0xFF5A552F),
        );
      case PreviousChoicePillType.exception:
        return const _PillColors(
          background: Color(0xFF4A211B),
          foreground: Color(0xFFFF4E2F),
          border: Color(0xFF5A2A22),
        );
    }
  }

  switch (type) {
    case PreviousChoicePillType.cuisine:
      return const _PillColors(
        background: Color(0xFFFFEDDE),
        foreground: Color(0xFFEE8C04),
        border: Color(0xFFFFD7BB),
      );
    case PreviousChoicePillType.mood:
      return const _PillColors(
        background: Color(0xFFFFFBDE),
        foreground: Color(0xFFEECF04),
        border: Color(0xFFF3E9A6),
      );
    case PreviousChoicePillType.exception:
      return const _PillColors(
        background: Color(0xFFFFE5DE),
        foreground: Color(0xFFEE2304),
        border: Color(0xFFFFC5B8),
      );
  }
}

class _MatchedCard extends StatelessWidget {
  const _MatchedCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Previous total dishes',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            count == 1 ? 'dish' : 'dishes',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.bolt_rounded, color: colors.warning, size: 22),
        ],
      ),
    );
  }
}
