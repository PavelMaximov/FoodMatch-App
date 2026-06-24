import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

class ActiveSessionChoiceScreen extends StatelessWidget {
  const ActiveSessionChoiceScreen({
    super.key,
    required this.sessionLabel,
    required this.onContinue,
    required this.onStartNew,
  });

  final String sessionLabel;
  final VoidCallback onContinue;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Continue where\nyou left off?',
            style: GoogleFonts.fredoka(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You already have an active swipe session.',
            style: GoogleFonts.nunito(
              fontSize: 16,
              height: 1.35,
              color: const Color(0xFF7A7270),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8E0DD)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDDE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    sessionLabel.toLowerCase().contains('solo')
                        ? Icons.person_rounded
                        : Icons.group_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        sessionLabel,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose whether to resume it or start fresh.',
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
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onStartNew,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              child: const Text('Start new'),
            ),
          ),
        ],
      ),
    );
  }
}
