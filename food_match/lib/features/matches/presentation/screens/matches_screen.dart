import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/match_item.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../shared/widgets/media/safe_avatar_image.dart';
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
    final List<MatchItem> matches = context.select<MatchProvider, List<MatchItem>>((MatchProvider p) => p.matches);
    final bool isLoading = context.select<MatchProvider, bool>((MatchProvider p) => p.isLoading);
    final String? error = context.select<MatchProvider, String?>((MatchProvider p) => p.error);
    final Set<String> savedDishIds = context.select<FavoritesProvider, Set<String>>((FavoritesProvider p) => p.savedDishIds);
    final bool isSoloMode = context.select<MatchProvider, bool>((MatchProvider p) => p.isSoloMode);
    final bool Function(String) isFavoriteUpdating = context.read<FavoritesProvider>().isUpdating;
    final Couple? currentCouple = context.select<CoupleProvider, Couple?>((CoupleProvider p) => p.currentCouple);
    final String? currentUserId = context.select<AuthProvider, String?>((AuthProvider p) => p.currentUser?.id);
    final CoupleMemberProfile? partner = resolvePartnerProfile(
      couple: currentCouple,
      currentUserId: currentUserId,
    );
    final String partnerName = resolvePartnerDisplayName(
      couple: currentCouple,
      currentUserId: currentUserId,
      fallback: AppStrings.yourPartner,
    );
    final String? partnerAvatarUrl = partner?.avatarUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 20),
              _Header(
                isSoloMode: isSoloMode,
                partnerName: partnerName,
                partnerAvatarUrl: partnerAvatarUrl,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Expanded(child: _buildBody(matches, isLoading, error, savedDishIds, isFavoriteUpdating, isSoloMode)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(List<MatchItem> matches, bool isLoading, String? error, Set<String> savedDishIds, bool Function(String) isFavoriteUpdating, bool isSoloMode) {
    if (isLoading && matches.isEmpty) {
      return ListView.builder(
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppDimensions.paddingS),
          child: ShimmerListTile(),
        ),
      );
    }

    if (error != null && matches.isEmpty) {
      return ErrorState(
        message: error,
        onRetry: () => context.read<MatchProvider>().loadMatches(force: true),
      );
    }

    if (matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => context.read<MatchProvider>().loadMatches(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            const SizedBox(height: 120),
            EmptyState(
              icon: Icons.favorite_border,
              title: 'No matches yet',
              subtitle: isSoloMode
                  ? 'Your solo likes will appear here.'
                  : 'Start swiping with your partner to find dishes you both like.',
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
        itemCount: matches.length,
        itemBuilder: (BuildContext context, int index) {
          final dish = matches[index].dish;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingS),
            child: DishCompactCard(
              key: ValueKey<String>(dish.id),
              dish: dish,
              isSaved: savedDishIds.contains(dish.id),
              onTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
              onFavoriteTap: isFavoriteUpdating(dish.id) ? null : () => context.read<FavoritesProvider>().toggleFavorite(dish),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isSoloMode,
    required this.partnerName,
    this.partnerAvatarUrl,
  });

  final bool isSoloMode;
  final String partnerName;
  final String? partnerAvatarUrl;

  @override
  Widget build(BuildContext context) {
    if (isSoloMode) {
      return Text(
        "Dishes you've liked",
        style: AppTextStyles.pageTitle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.matches,
          style: AppTextStyles.pageTitle,
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
      return SafeAvatarImage(
        imageUrl: avatarUrl,
        size: 30,
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
