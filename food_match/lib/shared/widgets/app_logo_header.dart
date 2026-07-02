import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/theme_extensions.dart';

class AppLogoHeader extends StatelessWidget {
  final bool showSubtitle;

  const AppLogoHeader({super.key, this.showSubtitle = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SvgPicture.asset(
          'assets/logos/foodmatch_logo.svg',
          width: 260,
          height: 78,
          placeholderBuilder: (BuildContext context) => Icon(
            Icons.restaurant_menu,
            size: 64,
            color: context.fmColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (showSubtitle) ...<Widget>[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              AppStrings.appTagline,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: context.fmColors.textSecondary,
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
