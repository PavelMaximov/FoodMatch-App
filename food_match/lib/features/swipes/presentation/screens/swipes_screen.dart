import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../couple/presentation/screens/connect_couple_screen.dart';
import '../../../matches/logic/match_provider.dart';
import '../../logic/swipe_provider.dart';
import '../widgets/swipe_card_widget.dart';

class SwipesScreen extends StatefulWidget {
  const SwipesScreen({super.key});

  @override
  State<SwipesScreen> createState() => _SwipesScreenState();
}

class _SwipesScreenState extends State<SwipesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SwipeProvider>().loadDeck();
      context.read<MatchProvider>().loadMatches();
    });
  }

  Future<void> _openConnectSessionBottomSheet() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXL),
            ),
            child: const ConnectCoupleScreen(isBottomSheet: true),
          ),
        );
      },
    );
  }

  Future<void> _manualSwipe(bool like) async {
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final swipedDish = swipeProvider.currentDish;
    final result = like ? await swipeProvider.like() : await swipeProvider.dislike();

    if (!mounted) {
      return;
    }

    if (result is Map<String, dynamic> && result['isMatch'] == true && swipedDish != null) {
      context.push('/match-overlay', extra: swipedDish);
    }
  }

  Widget _buildDeckArea(SwipeProvider swipeProvider) {
    if (swipeProvider.isLoading && swipeProvider.deck.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
        child: ShimmerCard(),
      );
    }

    if (swipeProvider.error != null && swipeProvider.deck.isEmpty) {
      return ErrorState(
        message: swipeProvider.error!,
        onRetry: swipeProvider.loadDeck,
      );
    }

    if (swipeProvider.isDeckEmpty) {
      return EmptyState(
        icon: Icons.restaurant,
        title: 'No more dishes!',
        subtitle: 'Refresh to load more',
        buttonText: 'Refresh',
        onButtonPressed: swipeProvider.loadDeck,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      child: CardSwiper(
        key: ValueKey<int>(swipeProvider.currentIndex),
        cardsCount: swipeProvider.deck.length,
        initialIndex: swipeProvider.currentIndex,
        numberOfCardsDisplayed: 2,
        cardBuilder: (BuildContext context, int index, _, __) {
          return SwipeCardWidget(dish: swipeProvider.deck[index]);
        },
        onSwipe: (int previousIndex, int? currentIndex, CardSwiperDirection direction) {
          if (direction == CardSwiperDirection.right) {
            context.read<SwipeProvider>().like();
          } else if (direction == CardSwiperDirection.left) {
            context.read<SwipeProvider>().dislike();
          }
          return true;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CoupleProvider coupleProvider = context.watch<CoupleProvider>();
    final SwipeProvider swipeProvider = context.watch<SwipeProvider>();
    final int connectedCount = coupleProvider.currentCouple?.members.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM,
                AppDimensions.paddingS,
                AppDimensions.paddingM,
                AppDimensions.paddingM,
              ),
              child: Row(
                children: <Widget>[
                  _TopChip(
                    label: 'Connect session',
                    backgroundColor: AppColors.primary,
                    textColor: Colors.white,
                    onPressed: _openConnectSessionBottomSheet,
                  ),
                  const Spacer(),
                  _TopChip(
                    label: 'Connected $connectedCount/2',
                    backgroundColor: AppColors.chipBg,
                    textColor: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
            Expanded(child: _buildDeckArea(swipeProvider)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingL,
                AppDimensions.paddingM,
                AppDimensions.paddingL,
                AppDimensions.paddingL,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _CircleActionButton(
                    size: 44,
                    icon: Icons.chevron_left,
                    iconColor: AppColors.textSecondary,
                    onPressed: () {},
                  ),
                  _CircleActionButton(
                    size: AppDimensions.swipeButtonSize,
                    icon: Icons.close,
                    iconColor: AppColors.textPrimary,
                    onPressed: swipeProvider.isLoading ? null : () => _manualSwipe(false),
                  ),
                  _CircleActionButton(
                    size: AppDimensions.swipeButtonSize,
                    icon: Icons.restaurant,
                    backgroundColor: AppColors.primary,
                    iconColor: Colors.white,
                    borderColor: AppColors.primary,
                    onPressed: swipeProvider.isLoading ? null : () => _manualSwipe(true),
                  ),
                  _CircleActionButton(
                    size: 44,
                    icon: Icons.refresh,
                    iconColor: AppColors.textSecondary,
                    onPressed: swipeProvider.isLoading ? null : swipeProvider.loadDeck,
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

class _TopChip extends StatelessWidget {
  const _TopChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 12,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.size,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.backgroundColor = Colors.white,
    this.borderColor = AppColors.divider,
  });

  final double size;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onPressed == null ? AppColors.chipBg : backgroundColor,
        border: Border.all(color: borderColor),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor),
      ),
    );
  }
}
