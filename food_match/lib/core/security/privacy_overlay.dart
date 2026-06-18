import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.background,
                    Color(0xFFFFE4D8),
                    Color(0xFFFFC6B8),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.restaurant_menu,
                      color: AppColors.primary,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'FoodMatch',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
