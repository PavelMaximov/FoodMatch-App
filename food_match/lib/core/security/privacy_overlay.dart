import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';


class PrivacyOverlay extends StatelessWidget {
  const PrivacyOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.white,
              child: const Center(
                child: _PrivacyLogo(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyLogo extends StatelessWidget {
  const _PrivacyLogo();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/logos/foodmatch_logo_vert.svg',
      width: 128,
      height: 128,
      fit: BoxFit.contain,
    );
  }
}
