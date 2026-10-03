import 'package:flutter/material.dart';

import '../../../../data/models/dish.dart';
import '../../logic/swipe_provider.dart';
import 'swipe_card_widget.dart';
import 'swipeable_stack.dart';

/// Renders the current deck; the screen owns session and action coordination.
class SwipeDeckView extends StatelessWidget {
  const SwipeDeckView({
    super.key,
    required this.provider,
    required this.stackKey,
    required this.isCardActionInProgress,
    required this.onLike,
    required this.onDislike,
    required this.onUndo,
    required this.onInfoTap,
    required this.onSwipe,
  });

  final SwipeProvider provider;
  final GlobalKey<SwipeableStackState> stackKey;
  final bool isCardActionInProgress;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onUndo;
  final void Function(BuildContext context, Dish dish) onInfoTap;
  final ValueChanged<SwipeDirection> onSwipe;

  @override
  Widget build(BuildContext context) {
    return SwipeableStack(
      key: stackKey,
      itemCount: provider.deck.length - provider.currentIndex,
      canSwipe: !provider.isLoading &&
          !provider.isSendingSwipe &&
          !isCardActionInProgress,
      cardBuilder: (BuildContext context, int index) {
        final dish = provider.deck[provider.currentIndex + index];
        return SwipeCardWidget(
          key: ValueKey<String>(dish.id),
          dish: dish,
          onLike: provider.isLoading || provider.isSendingSwipe || isCardActionInProgress
              ? null
              : onLike,
          onDislike: provider.isLoading || provider.isSendingSwipe || isCardActionInProgress
              ? null
              : onDislike,
          onBack: provider.canUndo && !provider.isSendingSwipe && !isCardActionInProgress
              ? onUndo
              : null,
          onInfoTap: () => onInfoTap(context, dish),
          showSeenBadge: provider.isSeenDish(dish.id),
        );
      },
      onSwipe: (int index, SwipeDirection direction) {
        onSwipe(direction);
      },
    );
  }
}
