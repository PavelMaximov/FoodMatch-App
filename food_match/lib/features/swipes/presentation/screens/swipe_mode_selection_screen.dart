import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

enum SwipeModeChoice { solo, paired }

class SwipeModeSelectionScreen extends StatefulWidget {
  const SwipeModeSelectionScreen({
    super.key,
    required this.onSolo,
    required this.onPairUp,
  });

  final VoidCallback onSolo;
  final VoidCallback onPairUp;

  @override
  State<SwipeModeSelectionScreen> createState() =>
      _SwipeModeSelectionScreenState();
}

class _SwipeModeSelectionScreenState extends State<SwipeModeSelectionScreen> {
  SwipeModeChoice _selected = SwipeModeChoice.solo;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'How do you want\nto swipe?',
            style: GoogleFonts.fredoka(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.08,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose solo to explore on your own, or pair up to find a dish you both want.',
            style: GoogleFonts.nunito(
              fontSize: 15,
              height: 1.35,
              color: const Color(0xFF7A7270),
            ),
          ),
          const SizedBox(height: 22),
          _ModeCard(
            selected: _selected == SwipeModeChoice.solo,
            icon: Icons.person_rounded,
            title: 'Solo',
            subtitle: 'Swipe through dishes just for yourself.',
            info:
                'Matches are saved to your personal list right away — no waiting on anyone else.',
            infoColor: const Color(0xFFC5AB00),
            infoBg: const Color(0xFFFFFBDE),
            onTap: () => setState(() => _selected = SwipeModeChoice.solo),
          ),
          const SizedBox(height: 14),
          _ModeCard(
            selected: _selected == SwipeModeChoice.paired,
            icon: Icons.group_rounded,
            title: 'Pair up',
            badge: '2 people',
            subtitle: 'Swipe together with a partner in real time.',
            info:
                'You\'ll send an invite link. A dish becomes a match only when you both swipe right.',
            infoColor: const Color(0xFF7A7270),
            infoBg: const Color(0xFFF7F7F7),
            onTap: () => setState(() => _selected = SwipeModeChoice.paired),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8EF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF2E8B57),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can switch modes anytime from the Connect session button.',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E8B57),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected == SwipeModeChoice.solo
                  ? widget.onSolo
                  : widget.onPairUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFD5115),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(
                _selected == SwipeModeChoice.solo
                    ? 'Continue with Solo'
                    : 'Continue with Pair up',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    this.badge,
    required this.subtitle,
    required this.info,
    required this.infoColor,
    required this.infoBg,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String? badge;
  final String subtitle;
  final String info;
  final Color infoColor;
  final Color infoBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFEE8C04) : const Color(0xFFE2DAD6),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
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
                  child: Icon(
                    icon,
                    color: const Color(0xFFEE8C04),
                  ),
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
                              color: Colors.black,
                            ),
                          ),
                          if (badge != null) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
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
                Radio<bool>(
                  value: true,
                  groupValue: selected,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: infoColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: infoColor,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
