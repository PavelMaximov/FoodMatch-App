import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/food_match_loader.dart';

class SwipeContinuationWaiting extends StatelessWidget {
  const SwipeContinuationWaiting({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.fmColors.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            children: <Widget>[
              const Spacer(),
              Image.asset(
                'assets/media/Waiting_for_partner.png',
                height: 240,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for your partner',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontWeight: FontWeight.w700,
                  fontSize: 34,
                  color: context.fmColors.textPrimary,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  'Your partner needs to confirm continuing the last session.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: context.fmColors.textSecondary,
                    height: 1.38,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const FoodMatchLoader(size: 144),
              const SizedBox(height: 6),
              TextButton(
                onPressed: onBack,
                child: const Text('Back'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

}
