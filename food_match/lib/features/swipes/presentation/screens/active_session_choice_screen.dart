import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';

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
    final FoodMatchThemeColors colors = context.fmColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Continue where\nyou left off?',
            style: GoogleFonts.nunito(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Choose whether to continue your previous setup or start a new session.',
            style: GoogleFonts.nunito(
              fontSize: 16,
              height: 1.35,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(36),
                  ),
                  child: Icon(
                    sessionLabel.toLowerCase().contains('solo') ? Icons.person_rounded : Icons.group_rounded,
                    color: colors.primary,
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
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Continue as before or create a new session.',
                        style: GoogleFonts.nunito(fontSize: 14, color: colors.textSecondary),
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
                backgroundColor: colors.buttonPrimaryBackground,
                foregroundColor: colors.buttonPrimaryText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              child: const Text('Continue as before'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onStartNew,
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.buttonSecondaryBackground,
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              child: const Text('Create a new session'),
            ),
          ),
        ],
      ),
    );
  }
}
