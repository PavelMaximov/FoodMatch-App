import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/animations/app_motion.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/cloudinary_image_url.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/models/match_item.dart';
import '../../../../data/models/prepared_deck.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../matches/logic/match_provider.dart';
import '../../../matches/presentation/widgets/match_notification_overlay.dart';
import '../../logic/pre_swipe_provider.dart';
import '../../logic/swipe_provider.dart';
import '../widgets/session_settings_sheet.dart';
import '../widgets/swipe_card_widget.dart';
import '../widgets/swipeable_stack.dart';
import 'active_session_choice_screen.dart';
import 'deck_end_choice_screen.dart';
import 'pair_connection_step_screen.dart';
import 'pre_swipe_filter_screen.dart';
import 'swipe_mode_selection_screen.dart';

enum _ActiveSessionChoiceType { solo, paired }

class SwipesScreen extends StatefulWidget {
  const SwipesScreen({super.key});

  @override
  State<SwipesScreen> createState() => _SwipesScreenState();
}

class _SwipesScreenState extends State<SwipesScreen> {
  SwipeableStackController _swiperController = SwipeableStackController();
  String? _swipeStackIdentity;
  bool _isOpeningPreSwipe = false;
  bool _isCardActionInProgress = false;
  bool _showPairConnectionStep = false;
  bool _isHandlingSessionEnded = false;
  CoupleProvider? _coupleProvider;
  bool _isLoadingInitialSession = false;
  String? _initialSessionError;
  _ActiveSessionChoiceType? _activeSessionChoiceType;
  final Set<String> _preloadedImageUrls = <String>{};
  Timer? _pairMatchPollingTimer;
  Timer? _pairMatchBurstTimer;
  DateTime? _pairMatchBurstUntil;
  OverlayEntry? _matchNotificationEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final CoupleProvider coupleProvider = context.read<CoupleProvider>();
      _coupleProvider = coupleProvider;
      coupleProvider.addListener(_handleCoupleSessionEnded);
      coupleProvider.startFilterStatePolling(reason: 'swipes_screen');
      _loadExistingBackendDeckOrStart();
    });
  }

  @override
  void dispose() {
    _coupleProvider?.removeListener(_handleCoupleSessionEnded);
    _coupleProvider?.stopFilterStatePolling(reason: 'swipes_dispose');
    _stopPairMatchPolling();
    _stopPairMatchBurstPolling();
    _dismissMatchNotification();
    super.dispose();
  }

  void _handleCoupleSessionEnded() {
    unawaited(_showCoupleSessionEndedDialog());
  }

  Future<void> _showCoupleSessionEndedDialog() async {
    final CoupleProvider? coupleProvider = _coupleProvider;
    final String? message = coupleProvider?.sessionEndedMessage;
    if (!mounted || coupleProvider == null || message == null || _isHandlingSessionEnded) {
      return;
    }
    _isHandlingSessionEnded = true;
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    swipeProvider.resetToModeSelection();
    swipeProvider.clearPreparedDeck();
    context.read<PreSwipeProvider>().clearDraft();
    _stopPairMatchPolling();
    context.read<MatchProvider>().clearMatches();
    setState(() {
      _activeSessionChoiceType = null;
      _showPairConnectionStep = false;
      _isOpeningPreSwipe = false;
    });

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Session ended'),
        content: const Text('Your partner has left this session. You can start a new session or join another one.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) {
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    }
    coupleProvider.clearSessionEndedMessage();
    if (mounted) {
      setState(() => _isHandlingSessionEnded = false);
    } else {
      _isHandlingSessionEnded = false;
    }
  }

  Future<void> _loadExistingBackendDeckOrStart() async {
    if (_isLoadingInitialSession) {
      return;
    }
    setState(() {
      _isLoadingInitialSession = true;
      _initialSessionError = null;
      _showPairConnectionStep = false;
      _isOpeningPreSwipe = false;
      _activeSessionChoiceType = null;
    });

    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    swipeProvider.setActiveUser(userId);

    try {
      await coupleProvider.loadCouple(force: true);
      if (!mounted) {
        return;
      }

      if (coupleProvider.error != null && !coupleProvider.hasCouple) {
        setState(() => _initialSessionError = coupleProvider.error);
        return;
      }

      if (coupleProvider.hasCouple) {
        swipeProvider.setPairedMode();
        context.read<MatchProvider>().setActiveCouple(
              coupleProvider.currentCouple?.id,
              sessionStateVersion: coupleProvider.sessionStateVersion,
            );
        _startPairMatchPolling();
        await coupleProvider.refreshFilterState(reason: 'swipes_load_existing_deck');
        if (!mounted) {
          return;
        }
        swipeProvider.clearPreparedDeck();
        setState(() => _activeSessionChoiceType = _ActiveSessionChoiceType.paired);
        return;
      }

      setState(() => _showPairConnectionStep = false);
      final bool loadedSolo = await swipeProvider.loadActiveSoloSession();
      if (loadedSolo) {
        final MatchProvider matchProvider = context.read<MatchProvider>();
        _stopPairMatchPolling();
        matchProvider.setSoloSession(swipeProvider.activeSoloSessionId);
        await matchProvider.loadMatches(force: true, mode: 'solo', soloSessionId: swipeProvider.activeSoloSessionId);
        if (mounted) {
          setState(() => _activeSessionChoiceType = _ActiveSessionChoiceType.solo);
        }
      } else {
        swipeProvider.resetToModeSelection();
        context.read<MatchProvider>().clearMatches();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _initialSessionError = 'We couldn’t load your swipe session. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingInitialSession = false;
          _isOpeningPreSwipe = false;
        });
      } else {
        _isOpeningPreSwipe = false;
      }
    }
  }

  Future<void> _continueActiveSession() async {
    final _ActiveSessionChoiceType? choiceType = _activeSessionChoiceType;
    if (choiceType == null) {
      return;
    }
    setState(() => _activeSessionChoiceType = null);
    if (choiceType == _ActiveSessionChoiceType.solo) {
      final SwipeProvider swipeProvider = context.read<SwipeProvider>();
      final MatchProvider matchProvider = context.read<MatchProvider>();
      matchProvider.setSoloSession(swipeProvider.activeSoloSessionId);
      await matchProvider.loadMatches(
        force: true,
        mode: 'solo',
        soloSessionId: swipeProvider.activeSoloSessionId,
      );
      return;
    }
    await _continuePairedSession();
  }

  Future<void> _continuePairedSession() async {
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    swipeProvider.setPairedMode();
    context.read<MatchProvider>().setActiveCouple(
          coupleProvider.currentCouple?.id,
          sessionStateVersion: coupleProvider.sessionStateVersion,
        );
    _startPairMatchPolling();
    await coupleProvider.refreshFilterState(reason: 'swipes_continue_active_pair');
    if (!mounted) {
      return;
    }
    if (!coupleProvider.hasPartner) {
      debugPrint('[Deck] pair connection waiting for partner');
      swipeProvider.clearPreparedDeck();
      setState(() => _showPairConnectionStep = true);
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
    await _runPreSwipeFlow();
  }

  Future<void> _startNewFromActiveSession() async {
    final _ActiveSessionChoiceType? choiceType = _activeSessionChoiceType;
    if (choiceType == null) {
      return;
    }
    final bool confirmed = await _confirmStartNew(choiceType);
    if (!confirmed || !mounted) {
      return;
    }
    await _clearActiveSessionAndShowModeSelection(choiceType);
  }

  Future<void> _startNewFromDeckEnd(bool wasSoloMode) async {
    final bool confirmed = await _confirmStartNew(
      wasSoloMode ? _ActiveSessionChoiceType.solo : _ActiveSessionChoiceType.paired,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _clearActiveSessionAndShowModeSelection(
      wasSoloMode ? _ActiveSessionChoiceType.solo : _ActiveSessionChoiceType.paired,
    );
  }

  Future<bool> _confirmStartNew(_ActiveSessionChoiceType choiceType) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Start new session?'),
            content: Text(
              choiceType == _ActiveSessionChoiceType.solo
                  ? 'This will close your current solo session and clear the current swipe progress.'
                  : 'This will leave your current pair session and close the current invite/deck progress.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Start new'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _clearActiveSessionAndShowModeSelection(_ActiveSessionChoiceType choiceType) async {
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    if (choiceType == _ActiveSessionChoiceType.solo) {
      await swipeProvider.abandonActiveSoloSession();
    } else if (coupleProvider.hasCouple) {
      await coupleProvider.leaveCouple();
    }
    if (!mounted) {
      return;
    }
    swipeProvider.resetToModeSelection();
    context.read<PreSwipeProvider>().clearDraft();
    _stopPairMatchPolling();
    context.read<MatchProvider>().clearMatches();
    setState(() {
      _activeSessionChoiceType = null;
      _showPairConnectionStep = false;
      _isOpeningPreSwipe = false;
    });
  }

  Future<void> _runSoloPreSwipeFlow({PreSwipeFilterIntent intent = PreSwipeFilterIntent.createNewSession}) async {
    if (_isOpeningPreSwipe) return;
    _isOpeningPreSwipe = true;
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    swipeProvider.setActiveUser(context.read<AuthProvider>().currentUser?.id);
    final PreparedPoolResult? result = await Navigator.of(context).push<PreparedPoolResult>(MaterialPageRoute<PreparedPoolResult>(fullscreenDialog: true, builder: (_) => PreSwipeFilterScreen(mode: 'solo', intent: intent)));
    if (!mounted) { _isOpeningPreSwipe = false; return; }
    if (result != null && result.dishes.isNotEmpty) {
      _resetSwipeStackController();
      _stopPairMatchPolling();
      context.read<MatchProvider>().setSoloSession(swipeProvider.activeSoloSessionId);
      swipeProvider.applyPreparedDeck(result.dishes, preparedDeckMeta: result.preparedDeckMeta);
    }
    if (mounted) {
      setState(() => _isOpeningPreSwipe = false);
    } else {
      _isOpeningPreSwipe = false;
    }
  }

  Future<void> _runPreSwipeFlow({bool fromHeaderAction = false}) async {
    if (_isOpeningPreSwipe) {
      return;
    }

    _isOpeningPreSwipe = true;
    final CoupleProvider currentCoupleProvider = context.read<CoupleProvider>();
    if (!currentCoupleProvider.hasCouple || !currentCoupleProvider.hasPartner) {
      _isOpeningPreSwipe = false;
      if (mounted) {
        setState(() {
          _showPairConnectionStep = true;
          _isOpeningPreSwipe = false;
        });
      }
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
      if (mounted) {
        setState(() => _isOpeningPreSwipe = false);
      } else {
        _isOpeningPreSwipe = false;
      }
      return;
    }

    if (result.dishes.isEmpty) {
      swipeProvider.applyPreparedDeck(<Dish>[]);
      if (mounted) {
        setState(() => _isOpeningPreSwipe = false);
      } else {
        _isOpeningPreSwipe = false;
      }
      return;
    }

    swipeProvider.applyPreparedDeck(
      result.dishes,
      seenDishIds: result.seenDishIds,
      preparedDeckMeta: result.preparedDeckMeta,
    );
    _startPairMatchPolling();
    _resetSwipeStackController();

    final String? waitingMessage = _partnerWaitingMessage(
      coupleProvider: _coupleProvider ?? context.read<CoupleProvider>(),
      deckMeta: result.preparedDeckMeta ?? swipeProvider.preparedDeckMeta,
    );
    if (waitingMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(waitingMessage)),
      );
    }

    if (mounted) {
      setState(() => _isOpeningPreSwipe = false);
    } else {
      _isOpeningPreSwipe = false;
    }
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
        onOpenPairSetup: () {
          setState(() => _showPairConnectionStep = true);
        },
        onStartSoloSetup: () {
          setState(() => _showPairConnectionStep = false);
          _runSoloPreSwipeFlow();
        },
      ),
    );
  }

  void _startPairMatchPolling() {
    _pairMatchPollingTimer?.cancel();
    _pairMatchPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollForPairMatches());
    });
    unawaited(_pollForPairMatches(seedOnly: true));
  }

  void _stopPairMatchPolling() {
    _pairMatchPollingTimer?.cancel();
    _pairMatchPollingTimer = null;
    _stopPairMatchBurstPolling();
  }

  void _startPairMatchBurstPolling() {
    if (!mounted || context.read<SwipeProvider>().isSoloMode) {
      return;
    }
    _pairMatchBurstUntil = DateTime.now().add(const Duration(seconds: 9));
    if (_pairMatchBurstTimer != null) {
      return;
    }
    _pairMatchBurstTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      final DateTime? burstUntil = _pairMatchBurstUntil;
      if (!mounted ||
          context.read<SwipeProvider>().isSoloMode ||
          burstUntil == null ||
          DateTime.now().isAfter(burstUntil)) {
        _stopPairMatchBurstPolling();
        return;
      }
      unawaited(_pollForPairMatches());
    });
    unawaited(_pollForPairMatches());
  }

  void _stopPairMatchBurstPolling() {
    _pairMatchBurstTimer?.cancel();
    _pairMatchBurstTimer = null;
    _pairMatchBurstUntil = null;
  }

  Future<void> _pollForPairMatches({bool seedOnly = false}) async {
    if (!mounted) return;
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    if (swipeProvider.isSoloMode) return;
    final List<MatchItem> newMatches = await context.read<MatchProvider>().syncPairedMatchesForNotifications(seedOnly: seedOnly);
    if (!mounted || seedOnly || newMatches.isEmpty) return;
    _showMatchNotification(newMatches.first.dish.name);
  }

  void _showMatchNotification(String? dishName) {
    _dismissMatchNotification();
    final OverlayState overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext overlayContext) => MatchNotificationOverlay(
        dishName: dishName,
        onDismiss: _dismissMatchNotification,
        onView: () {
          if (mounted) {
            context.go('/matches');
          }
        },
      ),
    );
    _matchNotificationEntry = entry;
    overlay.insert(entry);
  }

  void _dismissMatchNotification() {
    _matchNotificationEntry?.remove();
    _matchNotificationEntry = null;
  }

  void _resetSwipeStackController() {
    _swiperController.reset();
    _swiperController = SwipeableStackController();
    _swipeStackIdentity = null;
  }


  void _handleSwipe(SwipeDirection direction) {
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final swipedDish = swipeProvider.currentDish;
    final bool wasSoloMode = swipeProvider.isSoloMode;
    final String? soloSessionId = swipeProvider.activeSoloSessionId;

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
      final bool createdMatch = result is Map<String, dynamic> &&
          result['swipe']?['matchCreated'] == true;
      if (createdMatch && swipedDish != null) {
        final String? matchId = result['swipe']?['matchId']?.toString();
        if (matchId != null && matchId.isNotEmpty) {
          context.read<MatchProvider>().markMatchSeen(matchId);
        }
        context.read<MatchProvider>().loadMatches(
              force: true,
              mode: wasSoloMode ? 'solo' : 'paired',
              soloSessionId: wasSoloMode ? soloSessionId : null,
            );
        if (wasSoloMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.92, end: 1),
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                builder: (BuildContext context, double scale, Widget? child) {
                  return Opacity(
                    opacity: scale.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.centerLeft,
                      child: child,
                    ),
                  );
                },
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.favorite, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Saved to Matches'),
                  ],
                ),
              ),
              duration: const Duration(milliseconds: 1400),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        context.push('/match-overlay', extra: swipedDish);
        return;
      }
      if (!wasSoloMode && result != null) {
        _startPairMatchBurstPolling();
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


  @override
  Widget build(BuildContext context) {
    final bool hasCouple = context.select<CoupleProvider, bool>((CoupleProvider p) => p.hasCouple);
    final bool bothConfirmed = context.select<CoupleProvider, bool>((CoupleProvider p) => p.bothConfirmed);
    final bool hasPartner = context.select<CoupleProvider, bool>((CoupleProvider p) => p.hasPartner);
    final bool isMyChoicesConfirmed = context.select<CoupleProvider, bool>((CoupleProvider p) => p.isMyChoicesConfirmed);
    final bool isSoloMode = context.select<SwipeProvider, bool>((SwipeProvider p) => p.isSoloMode);
    final bool deckIsEmpty = context.select<SwipeProvider, bool>((SwipeProvider p) => p.deck.isEmpty);
    final bool hasCurrentDeckCard = context.select<SwipeProvider, bool>((SwipeProvider p) => p.deck.isNotEmpty && !p.isDeckEmpty);
    final bool showActiveSessionChoice = !_isLoadingInitialSession && _activeSessionChoiceType != null;
    final bool showModeSelection = !_isLoadingInitialSession &&
        _activeSessionChoiceType == null &&
        !hasCouple &&
        !isSoloMode &&
        deckIsEmpty &&
        !_showPairConnectionStep;
    final bool showPairConnection = !_isLoadingInitialSession &&
        _activeSessionChoiceType == null &&
        (_showPairConnectionStep || (hasCouple && !hasPartner && !isSoloMode));
    final bool showHeaderActions = hasCurrentDeckCard && !showActiveSessionChoice && !showModeSelection && !showPairConnection && !_isOpeningPreSwipe;
    final FoodMatchThemeColors colors = context.fmColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (showHeaderActions)
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
                        color: colors.cardElevated,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                        border: Border.all(color: colors.favoriteBtn),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.settings_outlined,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Session',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.read<SwipeProvider>().isSoloMode ? _runSoloPreSwipeFlow(intent: PreSwipeFilterIntent.updateActiveSoloSession) : _runPreSwipeFlow(fromHeaderAction: true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.cardElevated,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                        border: Border.all(color: colors.favoriteBtn),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.tune,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Filters',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
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
                    if (_isLoadingInitialSession) {
                      return const ShimmerCard();
                    }

                    if (_initialSessionError != null) {
                      return ErrorState(
                        message: _initialSessionError!,
                        onRetry: _loadExistingBackendDeckOrStart,
                      );
                    }

                    if (showActiveSessionChoice) {
                      final _ActiveSessionChoiceType choiceType = _activeSessionChoiceType!;
                      return ActiveSessionChoiceScreen(
                        sessionLabel: choiceType == _ActiveSessionChoiceType.solo
                            ? 'Solo session'
                            : 'Pair session',
                        onContinue: _continueActiveSession,
                        onStartNew: _startNewFromActiveSession,
                      );
                    }

                    if (showModeSelection) {
                      return SwipeModeSelectionScreen(
                        onSolo: () {
                          setState(() => _showPairConnectionStep = false);
                          _runSoloPreSwipeFlow();
                        },
                        onPairUp: () {
                          context.read<SwipeProvider>().setPairedMode();
                          context.read<MatchProvider>().clearMatches();
                          setState(() => _showPairConnectionStep = true);
                        },
                      );
                    }

                    if (showPairConnection) {
                      if (provider.hasPreparedDeck || provider.deck.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            provider.clearPreparedDeck();
                          }
                        });
                      }
                      return PairConnectionStepScreen(
                        onBack: () => setState(() => _showPairConnectionStep = false),
                        onPairConnected: () async {
                          if (!mounted) return;
                          setState(() => _showPairConnectionStep = false);
                          await _runPreSwipeFlow();
                        },
                      );
                    }

                    if (hasCouple && hasPartner && !bothConfirmed && !provider.isSoloMode) {
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
                        onButtonPressed: () => provider.isSoloMode ? _runSoloPreSwipeFlow(intent: PreSwipeFilterIntent.updateActiveSoloSession) : _runPreSwipeFlow(fromHeaderAction: true),
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
                      final bool soloContext = provider.isSoloMode;
                      return DeckEndChoiceScreen(
                        isSoloMode: soloContext,
                        onUsePreviousFilter: () => soloContext
                            ? _runSoloPreSwipeFlow(intent: PreSwipeFilterIntent.updateActiveSoloSession)
                            : _runPreSwipeFlow(fromHeaderAction: true),
                        onStartNew: () => _startNewFromDeckEnd(soloContext),
                      );
                    }

                    final String stackIdentity =
                        '${provider.currentSwipeMode}-${provider.activeSoloSessionId ?? 'none'}-${provider.deckVersion}';
                    if (_swipeStackIdentity != stackIdentity) {
                      _swiperController.reset();
                      _swiperController = SwipeableStackController();
                      _swipeStackIdentity = stackIdentity;
                    }

                    return SwipeableStack(
                      controller: _swiperController,
                      key: ValueKey<String>(stackIdentity),
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
