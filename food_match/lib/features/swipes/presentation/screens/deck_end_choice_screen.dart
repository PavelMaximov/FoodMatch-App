import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

class DeckEndChoiceScreen extends StatelessWidget {
  const DeckEndChoiceScreen({
    super.key,
    required this.isSoloMode,
    required this.onUsePreviousFilter,
    required this.onStartNew,
  });

  final bool isSoloMode;
  final VoidCallback onUsePreviousFilter;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDDE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isSoloMode ? Icons.favorite_border : Icons.restaurant_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'You\'re done\nfor now',
            style: GoogleFonts.fredoka(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Want to keep going with this setup or start fresh?',
            style: GoogleFonts.nunito(
              fontSize: 17,
              height: 1.35,
              color: const Color(0xFF7A7270),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onUsePreviousFilter,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                textStyle: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              child: const Text('Use previous filter'),
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
