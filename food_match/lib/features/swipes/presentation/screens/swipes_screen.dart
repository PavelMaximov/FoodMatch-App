import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Consumer2<SwipeProvider, CoupleProvider>(
          builder: (BuildContext context, SwipeProvider provider, CoupleProvider coupleProvider, _) {
            if (provider.isLoading && provider.deck.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: ShimmerCard(),
              );
            }

            if (provider.error != null && provider.deck.isEmpty) {
              return ErrorState(
                message: provider.error!,
                onRetry: provider.loadDeck,
              );
            }

            if (provider.isDeckEmpty) {
              return EmptyState(
                icon: Icons.restaurant,
                title: 'No more dishes!',
                subtitle: 'Refresh to load more',
                buttonText: 'Refresh',
                onButtonPressed: provider.loadDeck,
              );
            }

            return Padding(
              padding: const EdgeInsets.all(8),
              child: CardSwiper(
                key: ValueKey<int>(provider.currentIndex),
                cardsCount: provider.deck.length - provider.currentIndex,
                numberOfCardsDisplayed: 2,
                cardBuilder: (BuildContext context, int index, _, __) {
                  final dish = provider.deck[provider.currentIndex + index];
                  return SwipeCardWidget(
                    dish: dish,
                    onLike: provider.isLoading ? null : () => _manualSwipe(true),
                    onDislike: provider.isLoading ? null : () => _manualSwipe(false),
                    onBack: null,
                    onRefresh: provider.isLoading ? null : provider.loadDeck,
                    onConnectSession: _openConnectSessionBottomSheet,
                    connectedCount: coupleProvider.currentCouple?.members.length ?? 0,
                  );
                },
                onSwipe: (int previousIndex, int? currentIndex, CardSwiperDirection direction) {
                  if (direction == CardSwiperDirection.right) {
                    provider.like();
                  } else if (direction == CardSwiperDirection.left) {
                    provider.dislike();
                  }
                  return true;
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
