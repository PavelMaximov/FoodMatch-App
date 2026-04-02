import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

class AppLogoHeader extends StatelessWidget {
  final bool showSubtitle;

  const AppLogoHeader({super.key, this.showSubtitle = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SvgPicture.asset(
          'assets/media/logofmblack1.svg',
          height: 80,
          colorFilter: const ColorFilter.mode(
            AppColors.textPrimary,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.appName,
          style: GoogleFonts.pacifico(
            fontSize: 32,
            color: AppColors.textPrimary,
          ),
        ),
        if (showSubtitle) ...<Widget>[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppStrings.appTagline,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}
