import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/cloudinary_image_url.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/models/prepared_deck.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../couple/presentation/widgets/connect_session_sheet.dart';
import '../../../matches/logic/match_provider.dart';
import '../../logic/pre_swipe_provider.dart';
import '../../logic/swipe_provider.dart';
import '../widgets/session_settings_sheet.dart';
import '../widgets/swipe_card_widget.dart';
import '../widgets/swipeable_stack.dart';
import 'pre_swipe_filter_screen.dart';
import 'swipe_mode_selection_screen.dart';

class SwipesScreen extends StatefulWidget {
  const SwipesScreen({super.key});

  @override
  State<SwipesScreen> createState() => _SwipesScreenState();
}

class _SwipesScreenState extends State<SwipesScreen> {
  final SwipeableStackController _swiperController = SwipeableStackController();
  bool _isOpeningPreSwipe = false;
  bool _isCardActionInProgress = false;
  CoupleProvider? _coupleProvider;
  final Set<String> _preloadedImageUrls = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final CoupleProvider coupleProvider = context.read<CoupleProvider>();
      _coupleProvider = coupleProvider;
      coupleProvider.startFilterStatePolling(reason: 'swipes_screen');
      _loadExistingBackendDeckOrStart();
    });
  }

  @override
  void dispose() {
    _coupleProvider?.stopFilterStatePolling(reason: 'swipes_dispose');
    super.dispose();
  }

  Future<void> _loadExistingBackendDeckOrStart() async {
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final CoupleProvider currentCoupleProvider = context.read<CoupleProvider>();
    if (!currentCoupleProvider.hasCouple) {
      final String? userId = context.read<AuthProvider>().currentUser?.id;
      swipeProvider.setActiveUser(userId);
      await swipeProvider.loadActiveSoloSession();
      _isOpeningPreSwipe = false;
      return;
    }
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    swipeProvider.setActiveUser(userId);

    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    if (coupleProvider.hasCouple) {
      await coupleProvider.refreshFilterState(reason: 'swipes_load_existing_deck');
      if (!mounted) {
        return;
      }
      if (!coupleProvider.bothConfirmed) {
        debugPrint('[Deck] local deck cleared reason=filters_not_ready');
        swipeProvider.clearPreparedDeck();
        await _runPreSwipeFlow();
        return;
      }
      final bool loaded = await swipeProvider.loadExistingPreparedDeck();
      if (loaded || !mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }
    await _runPreSwipeFlow();
  }

  Future<void> _runSoloPreSwipeFlow() async {
    if (_isOpeningPreSwipe) return;
    _isOpeningPreSwipe = true;
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    swipeProvider.setActiveUser(context.read<AuthProvider>().currentUser?.id);
    final PreparedPoolResult? result = await Navigator.of(context).push<PreparedPoolResult>(MaterialPageRoute<PreparedPoolResult>(fullscreenDialog: true, builder: (_) => const PreSwipeFilterScreen(mode: 'solo')));
    if (!mounted) { _isOpeningPreSwipe = false; return; }
    if (result != null && result.dishes.isNotEmpty) { swipeProvider.applyPreparedDeck(result.dishes, preparedDeckMeta: result.preparedDeckMeta); }
    _isOpeningPreSwipe = false;
  }

  Future<void> _runPreSwipeFlow({bool fromHeaderAction = false}) async {
    if (_isOpeningPreSwipe) {
      return;
    }

    _isOpeningPreSwipe = true;
    final CoupleProvider currentCoupleProvider = context.read<CoupleProvider>();
    if (!currentCoupleProvider.hasCouple) {
      _isOpeningPreSwipe = false;
      return;
    }
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
        builder: (_) => const PreSwipeFilterScreen(mode: 'paired'),
      ),
    );

    if (!mounted) {
      _isOpeningPreSwipe = false;
      return;
    }

    (_coupleProvider ?? context.read<CoupleProvider>())
        .startFilterStatePolling(reason: 'swipes_resumed_after_pre_swipe');

    if (result == null) {
      final CoupleProvider coupleProvider = _coupleProvider ?? context.read<CoupleProvider>();
      if (!swipeProvider.hasPreparedDeck && (!coupleProvider.hasCouple || coupleProvider.bothConfirmed)) {
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

    swipeProvider.applyPreparedDeck(
      result.dishes,
      seenDishIds: result.seenDishIds,
      preparedDeckMeta: result.preparedDeckMeta,
    );

    final String? waitingMessage = _partnerWaitingMessage(
      coupleProvider: _coupleProvider ?? context.read<CoupleProvider>(),
      deckMeta: result.preparedDeckMeta ?? swipeProvider.preparedDeckMeta,
    );
    if (waitingMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(waitingMessage)),
      );
    }

    _isOpeningPreSwipe = false;
  }


  void _preloadVisibleDishImages(SwipeProvider provider) {
    if (!mounted || provider.deck.isEmpty) return;

    final int start = provider.currentIndex;
    final int end = start + 3 < provider.deck.length ? start + 3 : provider.deck.length - 1;
    for (int index = start; index <= end; index += 1) {
      final String optimizedUrl = ImageUtils.getImageUrl(
        provider.deck[index].imageUrl,
        usage: ImageUsage.swipeCard,
      );
      if (optimizedUrl.isEmpty ||
          !CloudinaryImageUrl.isNetworkUrl(optimizedUrl) ||
          !_preloadedImageUrls.add(optimizedUrl)) {
        continue;
      }
      precacheImage(CachedNetworkImageProvider(optimizedUrl), context).catchError((_) {});
    }

    if (_preloadedImageUrls.length > 24) {
      _preloadedImageUrls.removeWhere((String url) =>
          !provider.deck.skip(provider.currentIndex).take(8).any((Dish dish) =>
              ImageUtils.getImageUrl(dish.imageUrl, usage: ImageUsage.swipeCard) == url));
    }
  }

  String? _partnerWaitingMessage({
    required CoupleProvider coupleProvider,
    PreparedDeckMeta? deckMeta,
  }) {
    if (!coupleProvider.hasCouple) {
      return null;
    }
    if (deckMeta?.bothConfirmed == true || deckMeta?.usedPartnerChoices == true) {
      return null;
    }
    if (coupleProvider.bothConfirmed) {
      return null;
    }

    final partnerChoices = coupleProvider.partnerChoices;
    if (partnerChoices == null || !partnerChoices.confirmed) {
      return 'Waiting for your partner to finish filters.';
    }
    return null;
  }

  void _showSessionSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SessionSettingsSheet(
        onOpenPairSetup: () => _showConnectSheet(context),
        onStartSoloSetup: _runSoloPreSwipeFlow,
      ),
    );
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
    final bool wasSoloMode = swipeProvider.isSoloMode;

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
        context.read<MatchProvider>().loadMatches(force: true, mode: wasSoloMode ? 'solo' : 'paired');
        if (wasSoloMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: <Widget>[
                  Icon(Icons.favorite, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Saved to Matches'),
                ],
              ),
              duration: Duration(milliseconds: 1400),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        context.push('/match-overlay', extra: swipedDish);
      }
    });
  }

  Future<void> _handleLike() async {
    if (_isCardActionInProgress) {
      return;
    }
    _isCardActionInProgress = true;
    try {
      _swiperController.swipeRight();
    } finally {
      _isCardActionInProgress = false;
    }
  }

  Future<void> _handleDislike() async {
    if (_isCardActionInProgress) {
      return;
    }
    _isCardActionInProgress = true;
    try {
      _swiperController.swipeLeft();
    } finally {
      _isCardActionInProgress = false;
    }
  }

  Future<void> _handleBack(SwipeProvider provider) async {
    if (_isCardActionInProgress || !provider.canUndo) {
      return;
    }
    _isCardActionInProgress = true;
    try {
      provider.undo();
    } finally {
      _isCardActionInProgress = false;
    }
  }

  Future<void> _handleReload(SwipeProvider provider) async {
    if (_isCardActionInProgress || provider.isLoading) {
      return;
    }
    _isCardActionInProgress = true;
    try {
      await provider.loadDeck();
    } finally {
      _isCardActionInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCouple = context.select<CoupleProvider, bool>((CoupleProvider p) => p.hasCouple);
    final bool bothConfirmed = context.select<CoupleProvider, bool>((CoupleProvider p) => p.bothConfirmed);
    final bool isMyChoicesConfirmed = context.select<CoupleProvider, bool>((CoupleProvider p) => p.isMyChoicesConfirmed);
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
                    onTap: () => _showSessionSettingsSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5B1C),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                      ),
                      child: Text(
                        'Session settings',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.read<SwipeProvider>().isSoloMode ? _runSoloPreSwipeFlow() : _runPreSwipeFlow(fromHeaderAction: true),
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
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filters',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:  AppColors.textPrimary,
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
                  left: 10,
                  right: 10,
                  bottom: 13,
                ),
                child: Consumer<SwipeProvider>(
                  builder: (BuildContext context, SwipeProvider provider, _) {
                    if (!hasCouple && !provider.isSoloMode && provider.deck.isEmpty) {
                      return SwipeModeSelectionScreen(
                        onSolo: _runSoloPreSwipeFlow,
                        onPairUp: () => _showConnectSheet(context),
                        onBack: () => context.go('/recipes'),
                      );
                    }

                    if (hasCouple && !bothConfirmed && !provider.isSoloMode) {
                      if (provider.hasPreparedDeck || provider.deck.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            provider.clearPreparedDeck();
                          }
                        });
                      }
                      return EmptyState(
                        icon: Icons.hourglass_empty,
                        title: isMyChoicesConfirmed
                            ? 'Waiting for your partner...'
                            : 'Complete your filters to prepare your shared deck.',
                        subtitle: isMyChoicesConfirmed
                            ? 'Your choices are saved. We’ll start swiping when your partner finishes their filters.'
                            : 'Your shared deck will be ready after both of you confirm filters.',
                        buttonText: 'Filters',
                        onButtonPressed: () => provider.isSoloMode ? _runSoloPreSwipeFlow() : _runPreSwipeFlow(fromHeaderAction: true),
                      );
                    }

                    if (provider.isLoading) {
                      return const ShimmerCard();
                    }

                    if (provider.error != null) {
                      return ErrorState(
                        message: provider.error!,
                        onRetry: provider.loadDeck,
                      );
                    }

                    _preloadVisibleDishImages(provider);

                    if (provider.isDeckEmpty) {
                      return EmptyState(
                        icon: Icons.restaurant,
                        title: 'No dishes found',
                        subtitle: 'Try removing some filters or choosing more cuisines.',
                        buttonText: 'Adjust filters',
                        onButtonPressed: () => provider.isSoloMode ? _runSoloPreSwipeFlow() : _runPreSwipeFlow(fromHeaderAction: true),
                      );
                    }

                    return SwipeableStack(
                      controller: _swiperController,
                      key: ValueKey<int>(provider.deckVersion),
                      itemCount: provider.deck.length - provider.currentIndex,
                      cardBuilder: (BuildContext context, int index) {
                        final dish = provider.deck[provider.currentIndex + index];
                        return SwipeCardWidget(
                          key: ValueKey<String>(dish.id),
                          dish: dish,
                          onLike: provider.isLoading || provider.isSendingSwipe || _isCardActionInProgress
                              ? null
                              : _handleLike,
                          onDislike: provider.isLoading || provider.isSendingSwipe || _isCardActionInProgress
                              ? null
                              : _handleDislike,
                          onBack: provider.canUndo && !provider.isSendingSwipe && !_isCardActionInProgress
                              ? () => _handleBack(provider)
                              : null,
                          onRefresh: provider.isLoading || provider.isSendingSwipe || _isCardActionInProgress
                              ? null
                              : () => _handleReload(provider),
                          onInfoTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
                          showSeenBadge: provider.isSeenDish(dish.id),
                        );
                      },
                      onSwipe: (int index, SwipeDirection direction) {
                        _handleSwipe(direction);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _preloadVisibleDishImages(provider);
                        });
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
