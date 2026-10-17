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
    required this.onTransitionChanged,
  });

  final SwipeProvider provider;
  final GlobalKey<SwipeableStackState> stackKey;
  final bool isCardActionInProgress;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onUndo;
  final void Function(BuildContext context, Dish dish) onInfoTap;
  final ValueChanged<SwipeDirection> onSwipe;
  final ValueChanged<bool> onTransitionChanged;

  @override
  Widget build(BuildContext context) {
    return SwipeableStack(
      key: stackKey,
      onTransitionChanged: onTransitionChanged,
      itemCount: provider.deck.length,
      currentIndex: provider.currentIndex,
      canSwipe: !provider.isLoading &&
          provider.canAcceptSwipe &&
          !isCardActionInProgress,
      cardBuilder: (BuildContext context, int index) {
        final dish = provider.deck[index];
        return SwipeCardWidget(
          key: ValueKey<String>(dish.id),
          dish: dish,
          onLike: !provider.canAcceptSwipe || isCardActionInProgress
              ? null
              : onLike,
          onDislike: !provider.canAcceptSwipe || isCardActionInProgress
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
