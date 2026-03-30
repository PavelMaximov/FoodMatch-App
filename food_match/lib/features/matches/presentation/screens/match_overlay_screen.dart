import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/constants/app_strings.dart';

class MatchOverlayScreen extends StatelessWidget {
  const MatchOverlayScreen({this.dish, super.key});

  final Dish? dish;

  @override
  Widget build(BuildContext context) {
    final CoupleProvider coupleProvider = context.watch<CoupleProvider>();
    final String? currentUserName = context.watch<AuthProvider>().currentUser?.displayName;
    final String partnerName = _resolvePartnerName(
      members: coupleProvider.currentCouple?.members,
      currentUserName: currentUserName,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.matchOverlayStart,
              AppColors.matchOverlayEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              children: <Widget>[
                const Spacer(),
                Text(AppStrings.congratulations, style: AppTextStyles.matchCongrats),
                const SizedBox(height: AppDimensions.paddingXS),
                Text(
                  AppStrings.youHaveA,
                  style: AppTextStyles.sectionHeader.copyWith(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  AppStrings.match,
                  style: AppTextStyles.matchCongrats.copyWith(
                    fontSize: 40,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingL),
                if (dish != null)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66FFFFFF),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                      child: CachedNetworkImage(
                        imageUrl: ImageUtils.getImageUrl(dish!.imageUrl),
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: AppDimensions.paddingL),
                Text(
                  '${AppStrings.youAnd} $partnerName',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.paddingXS),
                Text(
                  AppStrings.chosenSameDish,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Text(
                  AppStrings.nowYouHaveChoice,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                AppButton(
                  text: AppStrings.continueBrowsing,
                  onPressed: () => Navigator.pop(context),
                  darkBackground: true,
                ),
                const SizedBox(height: AppDimensions.paddingM - 4),
                AppButton(
                  text: AppStrings.goToMatchResults,
                  isOutlined: true,
                  darkBackground: true,
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/matches');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _resolvePartnerName({List<String>? members, String? currentUserName}) {
    if (members == null || members.isEmpty) {
      return AppStrings.yourPartner;
    }

    for (final String member in members) {
      if (member.isNotEmpty && member != currentUserName) {
        return member;
      }
    }

    return AppStrings.yourPartner;
  }
}
