import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../matches/logic/match_provider.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchProvider>().loadMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MatchProvider matchProvider = context.watch<MatchProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Recipes',
                    style: GoogleFonts.pacifico(
                      fontSize: 32,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your matched dishes',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context.read<MatchProvider>().loadMatches(),
                child: _buildBody(matchProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(MatchProvider matchProvider) {
    if (matchProvider.isLoading && matchProvider.matches.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (_, __) => const _GridShimmerCard(),
      );
    }

    if (matchProvider.error != null && matchProvider.matches.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: 420,
            child: ErrorState(
              message: matchProvider.error!,
              onRetry: () => context.read<MatchProvider>().loadMatches(),
            ),
          ),
        ],
      );
    }

    if (matchProvider.matches.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No recipes yet',
            subtitle: 'Start swiping to find dishes you both like',
          ),
        ],
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: matchProvider.matches.length,
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (BuildContext context, int index) {
        final Dish dish = matchProvider.matches[index];
        return _RecipeGridCard(dish: dish);
      },
    );
  }
}

class _RecipeGridCard extends StatelessWidget {
  const _RecipeGridCard({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: CachedNetworkImage(
                imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.image_not_supported_outlined),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    dish.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          dish.cuisine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_outward,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridShimmerCard extends StatelessWidget {
  const _GridShimmerCard();

  @override
  Widget build(BuildContext context) {
    return const ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusL)),
      child: ShimmerCard(),
    );
  }
}
