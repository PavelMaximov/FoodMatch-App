import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../couple/presentation/widgets/connect_session_sheet.dart';
import '../../../matches/logic/match_provider.dart';
import '../../logic/pre_swipe_provider.dart';
import '../../logic/swipe_provider.dart';
import '../widgets/swipe_card_widget.dart';
import '../widgets/swipeable_stack.dart';
import 'pre_swipe_filter_screen.dart';

class SwipesScreen extends StatefulWidget {
  const SwipesScreen({super.key});

  @override
  State<SwipesScreen> createState() => _SwipesScreenState();
}

class _SwipesScreenState extends State<SwipesScreen> {
  final SwipeableStackController _swiperController = SwipeableStackController();
  bool _isOpeningPreSwipe = false;
  int _lastSessionStateVersion = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastSessionStateVersion = context.read<CoupleProvider>().sessionStateVersion;
      _runPreSwipeFlow();
      context.read<MatchProvider>().loadMatches();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final int currentVersion = context.watch<CoupleProvider>().sessionStateVersion;
    if (_lastSessionStateVersion == -1) {
      _lastSessionStateVersion = currentVersion;
      return;
    }
    if (currentVersion != _lastSessionStateVersion) {
      _lastSessionStateVersion = currentVersion;
      context.read<SwipeProvider>().clearPreparedDeck();
    }
  }

  Future<void> _runPreSwipeFlow({bool fromHeaderAction = false}) async {
    if (_isOpeningPreSwipe) {
      return;
    }

    _isOpeningPreSwipe = true;
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    swipeProvider.setActiveUser(userId);

    if (!fromHeaderAction && swipeProvider.hasPreparedDeck) {
      _isOpeningPreSwipe = false;
      return;
    }

    final PreparedPoolResult? result = await Navigator.of(context).push<PreparedPoolResult>(
      MaterialPageRoute<PreparedPoolResult>(
        fullscreenDialog: true,
        builder: (_) => const PreSwipeFilterScreen(),
      ),
    );

    if (!mounted) {
      _isOpeningPreSwipe = false;
      return;
    }

    if (result == null) {
      if (!swipeProvider.hasPreparedDeck) {
        await swipeProvider.loadDeck();
      }
      _isOpeningPreSwipe = false;
      return;
    }

    if (result.dishes.isEmpty) {
      swipeProvider.applyPreparedDeck(<Dish>[]);
      _isOpeningPreSwipe = false;
      return;
    }

    swipeProvider.applyPreparedDeck(result.dishes, seenDishIds: result.seenDishIds);

    if (context.read<CoupleProvider>().partnerChoicesFor(userId ?? '').cuisines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for partner choices. Using your current filters for now.')),
      );
    }

    _isOpeningPreSwipe = false;
  }

  void _showConnectSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ConnectSessionSheet(),
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
          result['swipe']?['matchCreated'] == true &&
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
                    onTap: () => _runPreSwipeFlow(fromHeaderAction: true),
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
                          showSeenBadge: provider.isSeenDish(dish.id),
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
