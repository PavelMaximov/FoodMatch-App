import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../logic/match_provider.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchProvider>().loadMatches();
      context.read<CoupleProvider>().loadCouple();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MatchProvider matchProvider = context.watch<MatchProvider>();
    final CoupleProvider coupleProvider = context.watch<CoupleProvider>();
    final String? currentUserName = context.watch<AuthProvider>().currentUser?.displayName;
    final String partnerName = _resolvePartnerName(
      members: coupleProvider.currentCouple?.members,
      currentUserName: currentUserName,
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: AppDimensions.paddingS),
              _Header(partnerName: partnerName),
              const SizedBox(height: AppDimensions.paddingL),
              Expanded(child: _buildBody(matchProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(MatchProvider matchProvider) {
    if (matchProvider.isLoading && matchProvider.matches.isEmpty) {
      return ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppDimensions.paddingS),
          child: ShimmerListTile(),
        ),
      );
    }

    if (matchProvider.error != null && matchProvider.matches.isEmpty) {
      return ErrorState(
        message: matchProvider.error!,
        onRetry: () => context.read<MatchProvider>().loadMatches(),
      );
    }

    if (matchProvider.matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => context.read<MatchProvider>().loadMatches(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const <Widget>[
            SizedBox(height: 120),
            EmptyState(
              icon: Icons.favorite_border,
              title: 'No matches yet',
              subtitle: 'Swipe dishes together with your partner',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<MatchProvider>().loadMatches(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: matchProvider.matches.length,
        itemBuilder: (BuildContext context, int index) {
          final dish = matchProvider.matches[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
            child: Card(
              elevation: 2,
              shadowColor: AppColors.cardShadow,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                onTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.check_box_outline_blank,
                          size: 20,
                          color: AppColors.divider,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.paddingS),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              dish.title,
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dish.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: AppDimensions.paddingS),
                            Row(
                              children: <Widget>[
                                const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text('15 min.', style: AppTextStyles.bodySmall),
                                const SizedBox(width: AppDimensions.paddingM),
                                const Icon(Icons.people, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text('2 servings', style: AppTextStyles.bodySmall),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.paddingS),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                        child: CachedNetworkImage(
                          imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Colors.black12,
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _resolvePartnerName({List<String>? members, String? currentUserName}) {
    if (members == null || members.isEmpty) {
      return 'your partner';
    }

    for (final String member in members) {
      if (member.isNotEmpty && member != currentUserName) {
        return member;
      }
    }

    return 'your partner';
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.partnerName});

  final String partnerName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        RichText(
          text: TextSpan(
            children: <TextSpan>[
              TextSpan(
                text: 'Matches ',
                style: GoogleFonts.pacifico(
                  fontSize: 32,
                  color: AppColors.textPrimary,
                ),
              ),
              TextSpan(
                text: 'with',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                partnerName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.person, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ],
    );
  }
}
