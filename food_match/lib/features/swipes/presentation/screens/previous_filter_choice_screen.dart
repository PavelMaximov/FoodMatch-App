import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/user_profile.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF9),
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
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF2B2725)),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.history, size: 16, color: Color(0xFF7A7270)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastUsedLabel(preset.usedAt),
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: const Color(0xFF7A7270),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 64),
              Text(
                'Feeling it again\ntoday?',
                style: GoogleFonts.fredoka(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Here\'s what you picked last time.\nJump back in or start fresh.',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  height: 1.35,
                  color: const Color(0xFF7A7270),
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DEDA)),
      ),
      child: Column(
        children: <Widget>[
          _FilterSection(
            icon: Icons.room_service_outlined,
            label: 'Cuisine:',
            values: preset.cuisines,
            color: const Color(0xFFEE8C04),
            chipBg: const Color(0xFFFFEDDE),
          ),
          const Divider(height: 1, color: Color(0xFFEFE7E3)),
          _FilterSection(
            icon: Icons.auto_awesome,
            label: 'Mood:',
            values: preset.moods,
            color: const Color(0xFFEECF04),
            chipBg: const Color(0xFFFFFBDE),
          ),
          const Divider(height: 1, color: Color(0xFFEFE7E3)),
          _FilterSection(
            icon: Icons.do_not_disturb_alt_outlined,
            label: 'Exceptions:',
            values: preset.exclusions,
            color: const Color(0xFFEE2304),
            chipBg: const Color(0xFFFFE5DE),
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
    required this.color,
    required this.chipBg,
  });

  final IconData icon;
  final String label;
  final List<String> values;
  final Color color;
  final Color chipBg;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = values.isEmpty;
    final List<String> chips = isEmpty ? <String>['None'] : values;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: const Color(0xFF7A7270),
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
                    color: isEmpty ? const Color(0xFF8B8582) : color,
                    background: isEmpty ? const Color(0xFFF1ECE9) : chipBg,
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
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MatchedCard extends StatelessWidget {
  const _MatchedCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DEDA)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Previous total dishes',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2B2725),
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            count == 1 ? 'dish' : 'dishes',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7A7270),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.bolt_rounded, color: Color(0xFFEECF04), size: 22),
        ],
      ),
    );
  }
}
