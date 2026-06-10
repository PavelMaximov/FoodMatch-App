import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  static const String assetPath = 'assets/logos/foodmatch_logo.svg';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SvgPicture.asset(
        assetPath,
        width: 200,
        height: 90,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox(width: 200, height: 90),
      ),
    );
  }
}
