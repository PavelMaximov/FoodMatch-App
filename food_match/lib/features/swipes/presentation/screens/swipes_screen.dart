import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../couple/logic/couple_provider.dart';
import '../../../couple/presentation/screens/connect_couple_screen.dart';
import '../../../matches/logic/match_provider.dart';
import '../../logic/swipe_provider.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
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

  Future<void> _manualSwipe(bool like) async {
    final swipeProvider = context.read<SwipeProvider>();
    final swipedDish = swipeProvider.currentDish;
    final result = like ? await swipeProvider.like() : await swipeProvider.dislike();
    if (!mounted) return;
    if (result is Map<String, dynamic> && result['isMatch'] == true && swipedDish != null) {
      context.push('/match-overlay', extra: swipedDish);
    }
  }

  @override
  Widget build(BuildContext context) {
    final couple = context.watch<CoupleProvider>();
    final swipe = context.watch<SwipeProvider>();

    if (!couple.hasCouple) {
      return const ConnectCoupleScreen();
    }

    if (swipe.isLoading && swipe.deck.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerCard(),
      );
    }

    if (swipe.error != null && swipe.deck.isEmpty) {
      return ErrorState(
        message: swipe.error!,
        onRetry: () => context.read<SwipeProvider>().loadDeck(),
      );
    }

    if (swipe.isDeckEmpty) {
      return EmptyState(
        icon: Icons.restaurant,
        title: 'Блюда закончились!',
        subtitle: 'Загрузите ещё',
        buttonText: 'Обновить',
        onButtonPressed: () => context.read<SwipeProvider>().loadDeck(),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: <Widget>[
          Expanded(
            child: CardSwiper(
              cardsCount: swipe.deck.length,
              initialIndex: swipe.currentIndex,
              numberOfCardsDisplayed: 2,
              cardBuilder: (context, index, _, __) => SwipeCardWidget(dish: swipe.deck[index]),
              onSwipe: (previousIndex, currentIndex, direction) {
                if (direction == CardSwiperDirection.right) {
                  context.read<SwipeProvider>().like();
                } else if (direction == CardSwiperDirection.left) {
                  context.read<SwipeProvider>().dislike();
                }
                return true;
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              FloatingActionButton(
                heroTag: 'dislike',
                onPressed: swipe.isLoading ? null : () => _manualSwipe(false),
                backgroundColor: Colors.red,
                child: const Icon(Icons.close),
              ),
              const SizedBox(width: 32),
              FloatingActionButton(
                heroTag: 'like',
                onPressed: swipe.isLoading ? null : () => _manualSwipe(true),
                backgroundColor: Colors.green,
                child: const Icon(Icons.favorite),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
