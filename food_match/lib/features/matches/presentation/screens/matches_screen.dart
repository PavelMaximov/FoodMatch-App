import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../shared/widgets/safe_network_image.dart';
import '../../../../shared/widgets/dish_compact_card.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../favorites/logic/favorites_provider.dart';
import '../../logic/match_provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/models/couple.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CoupleProvider>().loadCouple();
      if (!mounted) return;
      context.read<MatchProvider>().loadMatches();
      context.read<FavoritesProvider>().loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MatchProvider matchProvider = context.watch<MatchProvider>();
    final CoupleProvider coupleProvider = context.watch<CoupleProvider>();
    final FavoritesProvider favoritesProvider = context.watch<FavoritesProvider>();
    final String? currentUserId = context.watch<AuthProvider>().currentUser?.id;
    final CoupleMemberProfile? partner = resolvePartnerProfile(
      couple: coupleProvider.currentCouple,
      currentUserId: currentUserId,
    );
    final String partnerName = resolvePartnerDisplayName(
      couple: coupleProvider.currentCouple,
      currentUserId: currentUserId,
      fallback: AppStrings.yourPartner,
    );
    final String? partnerAvatarUrl = partner?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: AppDimensions.paddingS),
              _Header(
                partnerName: partnerName,
                partnerAvatarUrl: partnerAvatarUrl,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Expanded(child: _buildBody(matchProvider, favoritesProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(MatchProvider matchProvider, FavoritesProvider favoritesProvider) {
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
        onRetry: () => context.read<MatchProvider>().loadMatches(force: true),
      );
    }

    if (matchProvider.matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => context.read<MatchProvider>().loadMatches(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            const SizedBox(height: 120),
            EmptyState(
              icon: Icons.favorite_border,
              title: 'No matches yet',
              subtitle: 'Start swiping with your partner to find dishes you both like.',
              buttonText: 'Start swiping',
              onButtonPressed: () => context.go('/swipes'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<MatchProvider>().loadMatches(force: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: matchProvider.matches.length,
        itemBuilder: (BuildContext context, int index) {
          final dish = matchProvider.matches[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
            child: DishCompactCard(
              dish: dish,
              isSaved: favoritesProvider.isFavorite(dish.id),
              onTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
              onFavoriteTap: () => context.read<FavoritesProvider>().toggleFavorite(dish),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.partnerName,
    this.partnerAvatarUrl,
  });

  final String partnerName;
  final String? partnerAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.matches,
          style: GoogleFonts.fredoka(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          children: <Widget>[
            Text(
              '${AppStrings.matchesWith} ',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            Flexible(
              child: Text(
                partnerName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 56 * 0.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _PartnerAvatar(
              partnerName: partnerName,
              avatarUrl: partnerAvatarUrl,
            ),
          ],
        ),
      ],
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({
    required this.partnerName,
    this.avatarUrl,
  });

  final String partnerName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final String initials = partnerName.trim().isEmpty ? '?' : partnerName.trim()[0].toUpperCase();
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return ClipOval(
        child: SafeNetworkImage(
          imageUrl: ImageUtils.getImageUrl(avatarUrl, usage: ImageUsage.avatar),
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          placeholderIcon: Icons.person,
          errorIcon: Icons.person,
        ),
      );
    }
    return _buildFallback(initials);
  }

  Widget _buildFallback(String initials) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: const Color(0xFFE6DFDC),
      child: Text(
        initials,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
