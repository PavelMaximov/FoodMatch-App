import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../couple/presentation/screens/connect_couple_screen.dart';
import '../../../matches/logic/match_provider.dart';
import '../../logic/swipe_provider.dart';
import '../widgets/swipe_card_widget.dart';
import '../widgets/swipeable_stack.dart';

class SwipesScreen extends StatefulWidget {
  const SwipesScreen({super.key});

  @override
  State<SwipesScreen> createState() => _SwipesScreenState();
}

class _SwipesScreenState extends State<SwipesScreen> {
  final SwipeableStackController _swiperController = SwipeableStackController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SwipeProvider>().loadDeck();
      context.read<MatchProvider>().loadMatches();
    });
  }

  Future<void> _showConnectSheet(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return const FractionallySizedBox(
          heightFactor: 0.92,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            child: ConnectCoupleScreen(isBottomSheet: true),
          ),
        );
      },
    );
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (_) => _FilterSheet(
        onCuisineSelected: (String? cuisine) {
          Navigator.pop(context);
          context.read<SwipeProvider>().loadDeck(cuisine: cuisine);
        },
      ),
    );
  }

  void _handleSwipe(SwipeDirection direction) {
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final swipedDish = swipeProvider.currentDish;

    Future<dynamic> swipeAction;
    if (direction == SwipeDirection.right) {
      swipeAction = swipeProvider.like();
    } else if (direction == SwipeDirection.left) {
      swipeAction = swipeProvider.dislike();
    } else {
      return;
    }

    swipeAction.then((dynamic result) {
      if (!mounted) {
        return;
      }
      if (result is Map<String, dynamic> &&
          result['isMatch'] == true &&
          swipedDish != null) {
        context.push('/match-overlay', extra: swipedDish);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(
                top: 30,
                bottom: 17,
                left: 16,
                right: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  GestureDetector(
                    onTap: () => _showConnectSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5B1C),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                      ),
                      child: Text(
                        'Connect session',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showFilterSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCD6D3),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.tune,
                            size: 16,
                            color: Color(0xFF1A1A1A),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filter',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 7,
                  right: 7,
                  bottom: 13,
                ),
                child: Consumer<SwipeProvider>(
                  builder: (BuildContext context, SwipeProvider provider, _) {
                    if (provider.isLoading) {
                      return const ShimmerCard();
                    }

                    if (provider.error != null) {
                      return ErrorState(
                        message: provider.error!,
                        onRetry: provider.loadDeck,
                      );
                    }

                    if (provider.isDeckEmpty) {
                      return EmptyState(
                        icon: Icons.restaurant,
                        title: AppStrings.noMoreDishes,
                        subtitle: AppStrings.refreshToLoad,
                        buttonText: AppStrings.refresh,
                        onButtonPressed: provider.loadDeck,
                      );
                    }

                    return SwipeableStack(
                      controller: _swiperController,
                      key: ValueKey<int>(provider.currentIndex),
                      itemCount: provider.deck.length - provider.currentIndex,
                      cardBuilder: (BuildContext context, int index) {
                        final dish = provider.deck[provider.currentIndex + index];
                        return SwipeCardWidget(
                          dish: dish,
                          onLike: provider.isLoading ? null : _swiperController.swipeRight,
                          onDislike: provider.isLoading ? null : _swiperController.swipeLeft,
                          onBack: provider.canUndo ? provider.undo : null,
                          onRefresh: provider.isLoading ? null : provider.loadDeck,
                        );
                      },
                      onSwipe: (int index, SwipeDirection direction) {
                        _handleSwipe(direction);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.onCuisineSelected});

  final Function(String?) onCuisineSelected;

  static const List<String> cuisines = <String>[
    'All',
    'American',
    'British',
    'Canadian',
    'Chinese',
    'Croatian',
    'Dutch',
    'Egyptian',
    'Filipino',
    'French',
    'Greek',
    'Indian',
    'Irish',
    'Italian',
    'Jamaican',
    'Japanese',
    'Kenyan',
    'Malaysian',
    'Mexican',
    'Moroccan',
    'Polish',
    'Portuguese',
    'Russian',
    'Spanish',
    'Thai',
    'Tunisian',
    'Turkish',
    'Ukrainian',
    'Vietnamese',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Filter by cuisine',
              style: GoogleFonts.pacifico(fontSize: 24),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cuisines.map((String c) {
                return GestureDetector(
                  onTap: () => onCuisineSelected(c == 'All' ? null : c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.chipBg,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      c,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
