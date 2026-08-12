import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/assets/app_empty_state_assets.dart';
import '../../../../core/widgets/food_match_loader.dart';
import '../../../../core/widgets/food_match_empty_state_image.dart';

class InlineDeckEndRestartCard extends StatelessWidget {
  const InlineDeckEndRestartCard({
    super.key,
    required this.isWaitingForPartner,
    required this.isLoading,
    required this.onRestart,
    this.onViewMatches,
    this.errorMessage,
  });

  final bool isWaitingForPartner;
  final bool isLoading;
  final VoidCallback? onRestart;
  final VoidCallback? onViewMatches;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final String title = isWaitingForPartner
        ? 'Waiting for partner'
        : 'Deck complete';
    final String subtitle = isWaitingForPartner
        ? 'Your partner also needs to finish this deck and restart.'
        : 'Would you like to change filters and start a new round?';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, minHeight: 520),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
            border: Border.all(color: colors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.32
                      : 0.10,
                ),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (isWaitingForPartner)
                _DeckStatusIcon(colors: colors)
              else
                FoodMatchEmptyStateImage(
                  assetPath: AppEmptyStateAssets.emptyDeckComplete,
                  width: 180,
                  height: 150,
                  fallback: Container(
                    width: 180,
                    height: 150,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  height: 1.35,
                  color: colors.textSecondary,
                ),
              ),
              if (errorMessage != null &&
                  errorMessage!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (isWaitingForPartner || isLoading) ...<Widget>[
                const FoodMatchLoader(size: 150),
              ] else ...<Widget>[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.buttonPrimaryBackground,
                      foregroundColor: colors.buttonPrimaryText,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36),
                      ),
                      textStyle: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Change filters'),
                  ),
                ),
                if (onViewMatches != null) ...<Widget>[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onViewMatches,
                    child: const Text('View matches'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckStatusIcon extends StatelessWidget {
  const _DeckStatusIcon({
    required this.colors,
    this.icon = Icons.hourglass_empty_rounded,
  });

  final FoodMatchThemeColors colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 88,
    height: 88,
    decoration: BoxDecoration(
      color: colors.primarySoft,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: colors.primary, size: 44),
  );
}
