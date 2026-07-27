import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/animations/app_motion.dart';
import '../../../../core/navigation/app_flow_coordinator.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/cloudinary_image_url.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_pending_overlay.dart';
import '../../../../core/widgets/food_match_loader.dart';
import '../../../../core/widgets/food_match_ripple.dart';
import '../../../../data/models/couple.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/models/match_item.dart';
import '../../../../data/models/prepared_deck.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/swipe_repository.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../shell/logic/nav_badge_animation_controller.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../matches/logic/match_provider.dart';
import '../../../matches/presentation/widgets/match_notification_overlay.dart';
import '../../logic/pre_swipe_provider.dart';
import '../../logic/swipe_provider.dart';
import '../widgets/inline_deck_end_restart_card.dart';
import '../widgets/session_settings_sheet.dart';
import '../widgets/swipe_card_widget.dart';
import '../widgets/swipeable_stack.dart';
import 'session_resume_choice_screen.dart';
import 'pair_connection_step_screen.dart';
import 'pre_swipe_filter_screen.dart';
import 'swipe_mode_selection_screen.dart';

enum _SessionResumeChoiceType { solo, paired }

enum _PreSwipeFlowOrigin {
  sessionResumeContinue,
  pairInvitationAccepted,
  filtersButton,
  pairConnectionReady,
  deckRestart,
}

extension _PreSwipeFlowOriginLogName on _PreSwipeFlowOrigin {
  String get logName {
    switch (this) {
      case _PreSwipeFlowOrigin.sessionResumeContinue:
        return 'sessionResumeContinue';
      case _PreSwipeFlowOrigin.pairInvitationAccepted:
        return 'pairInvitationAccepted';
      case _PreSwipeFlowOrigin.filtersButton:
        return 'filtersButton';
      case _PreSwipeFlowOrigin.pairConnectionReady:
        return 'pairConnectionReady';
      case _PreSwipeFlowOrigin.deckRestart:
        return 'deckRestart';
    }
  }
}

class SwipesScreen extends StatefulWidget {
  const SwipesScreen({super.key});

  @override
  State<SwipesScreen> createState() => _SwipesScreenState();
}

class _SwipesScreenState extends State<SwipesScreen> with WidgetsBindingObserver {
  final GlobalKey<SwipeableStackState> _swipeStackKey = GlobalKey<SwipeableStackState>();
  bool _isOpeningPreSwipe = false;
  bool _isCardActionInProgress = false;
  bool _showPairConnectionStep = false;
  bool _isHandlingSessionEnded = false;
  CoupleProvider? _coupleProvider;
  bool _isLoadingInitialSession = false;
  String? _initialSessionError;
  _SessionResumeChoiceType? _sessionResumeChoiceType;
  final AppFlowCoordinator _appFlow = const AppFlowCoordinator();
  final Set<String> _preloadedImageUrls = <String>{};
  Timer? _pairLifecyclePollingTimer;
  Timer? _pairMatchPollingTimer;
  Timer? _pairMatchBurstTimer;
  DateTime? _pairMatchBurstUntil;
  OverlayEntry? _matchNotificationEntry;
  DateTime? _lastPausedAt;
  Timer? _pairRestartPollingTimer;
  bool _isPairRestartWaiting = false;
  bool _isPairRestartLoading = false;
  String? _pairRestartError;
  int _loadedAuthBoundaryVersion = -1;
  bool _suppressPreviousChoiceAutoOpen = true;
  bool _pairDeckReadyAutoLoadEnabled = false;
  bool _isPairDeckReadyLoading = false;
  DateTime? _lastPairDeckReadyLoadAttemptAt;
  final Set<String> _shownPairFilterChangeInviteIds = <String>{};
  String? _lastPairFilterMarkerSessionId;
  int? _lastPairFilterMarkerGeneration;
  bool _pairFilterUpdateRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final CoupleProvider coupleProvider = context.read<CoupleProvider>();
      _coupleProvider = coupleProvider;
      coupleProvider.addListener(_handleCoupleSessionEnded);
      coupleProvider.startFilterStatePolling(reason: 'swipes_screen');
      _loadedAuthBoundaryVersion = context.read<AuthProvider>().authBoundaryVersion;
      _loadExistingBackendDeckOrStart();
    });
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final int authBoundaryVersion = context.watch<AuthProvider>().authBoundaryVersion;
    if (_loadedAuthBoundaryVersion == -1 || _loadedAuthBoundaryVersion == authBoundaryVersion) {
      return;
    }
    _loadedAuthBoundaryVersion = authBoundaryVersion;
    _resetLocalFlowStateForAuthBoundary();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadExistingBackendDeckOrStart();
      }
    });
  }

  void _resetLocalFlowStateForAuthBoundary() {
    _stopPairLifecyclePolling();
    _stopPairMatchPolling();
    _stopPairMatchBurstPolling();
    _stopPairRestartPolling();
    _resetPairFilterChangeDialogMarkers(reason: 'auth_boundary');
    _dismissMatchNotification();
    _resetSwipeStackController();
    setState(() {
      _showPairConnectionStep = false;
      _isHandlingSessionEnded = false;
      _initialSessionError = null;
      _pairFilterUpdateRequired = false;
      _sessionResumeChoiceType = null;
      _isPairRestartWaiting = false;
      _isPairRestartLoading = false;
      _pairRestartError = null;
      _suppressPreviousChoiceAutoOpen = true;
      _pairDeckReadyAutoLoadEnabled = false;
      _isPairDeckReadyLoading = false;
      _lastPairDeckReadyLoadAttemptAt = null;
    });
    context.read<CoupleProvider>().consumeOpenPreviousChoiceAfterInvite();
    debugPrint('[AppFlow] authBoundary startup: suppress previous choice auto-open');
  }

  @override
  void dispose() {
    _coupleProvider?.removeListener(_handleCoupleSessionEnded);
    _coupleProvider?.stopFilterStatePolling(reason: 'swipes_dispose');
    _stopPairLifecyclePolling();
    _stopPairMatchPolling();
    _stopPairMatchBurstPolling();
    _dismissMatchNotification();
    _stopPairRestartPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _lastPausedAt = DateTime.now();
      return;
    }

    if (state != AppLifecycleState.resumed) {
      return;
    }

    final DateTime resumedAt = DateTime.now();
    if (_appFlow.shouldResolveStartupOnResume(_lastPausedAt, resumedAt)) {
      unawaited(_loadExistingBackendDeckOrStart());
      return;
    }

    unawaited(_lightweightRefreshAfterShortResume());
  }

  Future<void> _lightweightRefreshAfterShortResume() async {
    if (!mounted) {
      return;
    }
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    await coupleProvider.handleAppResumed();
    if (!mounted) {
      return;
    }
    if (coupleProvider.sessionEndedMessage != null) {
      final StartupRouteDecision decision = await _appFlow.resolveStartupRoute(
        swipeRepository: context.read<SwipeRepository>(),
        swipeProvider: context.read<SwipeProvider>(),
        coupleProvider: coupleProvider,
      );
      _appFlow.logSessionInvalid(decision.route);
      if (mounted) {
        await _loadExistingBackendDeckOrStart();
      }
    }
  }


  Future<void> _handlePairNeedsResync() async {
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    if (!coupleProvider.consumeOpenSessionResumeForResync()) {
      return;
    }
    _stopPairLifecyclePolling();
    _stopPairMatchPolling();
    _stopPairMatchBurstPolling();
    _stopPairRestartPolling();
    context.read<SwipeProvider>().clearPreparedDeck();
    context.read<PreSwipeProvider>().clearDraft();
    context.read<MatchProvider>().clearMatches();
    setState(() {
      _showPairConnectionStep = false;
      _isOpeningPreSwipe = false;
      _isPairRestartWaiting = false;
      _isPairRestartLoading = false;
      _pairRestartError = null;
      _sessionResumeChoiceType = _SessionResumeChoiceType.paired;
    });
    debugPrint('[PairLifecycle] partnerChanged -> SessionResumeChoiceScreen');
    await _showPairResyncDialog(
      message: coupleProvider.pairNeedsResyncMessage,
    );
  }

  Future<void> _showPairResyncDialog({String? message}) async {
    if (!mounted) {
      return;
    }
    final bool isPartnerLeft = message == null ||
        message.contains('partner left') ||
        message.contains('Partner left');
    final String title = isPartnerLeft
        ? 'Partner left the session'
        : 'Session needs to be refreshed';
    final String body = isPartnerLeft
        ? 'Your partner left this session. You can wait for them to continue or start a new session.'
        : 'Your pair session changed. Please continue together or start a new session.';
    final bool startNew = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(isPartnerLeft ? 'Wait here' : 'OK'),
              ),
              if (isPartnerLeft)
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Start new session'),
                ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !startNew) {
      return;
    }
    context.read<SwipeProvider>().resetToModeSelection();
    context.read<PreSwipeProvider>().clearDraft();
    setState(() {
      _sessionResumeChoiceType = null;
      _showPairConnectionStep = false;
    });
  }

  void _resetPairFilterChangeDialogMarkers({required String reason}) {
    if (_shownPairFilterChangeInviteIds.isNotEmpty) {
      debugPrint('[PairFilterChange] clearing handled dialog markers reason=$reason');
    }
    _shownPairFilterChangeInviteIds.clear();
    _lastPairFilterMarkerSessionId = null;
    _lastPairFilterMarkerGeneration = null;
  }

  void _syncPairFilterChangeDialogMarkers(CoupleProvider coupleProvider) {
    final String? sessionId = coupleProvider.currentCouple?.id;
    final int generation = coupleProvider.currentCouple?.lifecycleGeneration ?? 0;
    if (sessionId != _lastPairFilterMarkerSessionId || generation != _lastPairFilterMarkerGeneration) {
      _resetPairFilterChangeDialogMarkers(reason: 'session_or_generation_changed');
      _lastPairFilterMarkerSessionId = sessionId;
      _lastPairFilterMarkerGeneration = generation;
    }
  }

  void _clearStalePairDeckSetupState({required String reason}) {
    debugPrint('[PairDeck] clearing stale local deck-end/setup state reason=$reason');
    setState(() {
      _sessionResumeChoiceType = null;
      _showPairConnectionStep = false;
      _isPairRestartWaiting = false;
      _isPairRestartLoading = false;
      _pairRestartError = null;
      _isOpeningPreSwipe = false;
      _suppressPreviousChoiceAutoOpen = false;
      _pairDeckReadyAutoLoadEnabled = true;
      _pairFilterUpdateRequired = false;
    });
    _resetPairFilterChangeDialogMarkers(reason: reason);
    context.read<PreSwipeProvider>().clearDraft();
  }

  Future<void> _loadCanonicalPairDeckAndShowSwipe({required String reason}) async {
    if (_isPairDeckReadyLoading || !mounted) {
      return;
    }
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    if (swipeProvider.isSoloMode) {
      return;
    }
    _isPairDeckReadyLoading = true;
    _lastPairDeckReadyLoadAttemptAt = DateTime.now();
    swipeProvider.clearDeckError(notify: false);
    setState(() {});
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    debugPrint('[PairFlow] both filters confirmed session=${coupleProvider.currentCouple?.id ?? 'none'} generation=${coupleProvider.currentCouple?.lifecycleGeneration ?? 0}');
    try {
      _clearStalePairDeckSetupState(reason: reason);
      swipeProvider.clearPreparedDeck();
      const List<Duration> retryDelays = <Duration>[
        Duration.zero,
        Duration(milliseconds: 700),
        Duration(milliseconds: 1200),
        Duration(milliseconds: 2000),
      ];
      for (int attempt = 0; attempt < retryDelays.length; attempt++) {
        if (retryDelays[attempt] > Duration.zero) {
          debugPrint('[PairDeck] canonical load retry attempt=$attempt reason=$reason');
          await Future<void>.delayed(retryDelays[attempt]);
        }
        if (!mounted) {
          return;
        }
        final bool loaded = await swipeProvider.loadExistingPreparedDeck(force: true);
        if (!mounted) {
          return;
        }
        if (loaded && swipeProvider.deck.isNotEmpty) {
          final PreparedDeckMeta? meta = swipeProvider.preparedDeckMeta;
          final Object generation = meta?.filtersHash ?? coupleProvider.currentCouple?.lifecycleGeneration ?? 0;
          debugPrint('[PairDeck] ready session=${coupleProvider.currentCouple?.id ?? 'none'} generation=$generation size=${swipeProvider.deck.length}');
          debugPrint('[PairDeck] canonical deck loaded session=${coupleProvider.currentCouple?.id ?? 'none'} generation=$generation size=${swipeProvider.deck.length}');
          debugPrint('[AppFlow] pair deck ready -> Swipe');
          _resetSwipeStackController();
          _startPairLifecyclePolling();
          _startPairMatchPolling();
          Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
          setState(() {});
          return;
        }
      }
      debugPrint('[PairDeck] canonical load exhausted retries reason=$reason');
      swipeProvider.setDeckError('Could not load the shared deck. Please try again.');
    } finally {
      _isPairDeckReadyLoading = false;
      if (mounted) {
        setState(() {});
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (mounted && _pairDeckReadyAutoLoadEnabled && context.read<SwipeProvider>().deck.isEmpty) {
            setState(() {});
          }
        });
      }
    }
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
    _stopPairRestartPolling();
    context.read<MatchProvider>().clearMatches();
    setState(() {
      _sessionResumeChoiceType = null;
      _showPairConnectionStep = false;
      _isOpeningPreSwipe = false;
      _isPairRestartWaiting = false;
      _isPairRestartLoading = false;
      _pairRestartError = null;
      _isPairRestartWaiting = false;
      _isPairRestartLoading = false;
      _pairRestartError = null;
      _isPairRestartWaiting = false;
      _isPairRestartLoading = false;
      _pairRestartError = null;
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
      _pairFilterUpdateRequired = false;
      _showPairConnectionStep = false;
      _isOpeningPreSwipe = false;
      _sessionResumeChoiceType = null;
      _suppressPreviousChoiceAutoOpen = true;
      _pairDeckReadyAutoLoadEnabled = false;
      _isPairDeckReadyLoading = false;
      _lastPairDeckReadyLoadAttemptAt = null;
    });

    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    swipeProvider.setActiveUser(userId);

    debugPrint('[PageLoad] start page=Swipe reason=route');
    try {
      await coupleProvider
          .loadCouple(force: true)
          .timeout(const Duration(seconds: 15));
      if (!mounted) {
        return;
      }

      if (coupleProvider.error != null && !coupleProvider.hasCouple) {
        debugPrint(
          '[PageLoad] retry reason=missingSessionDuringRouteTransition page=Swipe',
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        await coupleProvider
            .loadCouple(force: true)
            .timeout(const Duration(seconds: 15));
        if (coupleProvider.error != null && !coupleProvider.hasCouple) {
          setState(() => _initialSessionError = coupleProvider.error);
          debugPrint('[PageLoad] error page=Swipe error=${coupleProvider.error}');
          return;
        }
      }

      final StartupRouteDecision decision = await _appFlow
          .resolveStartupRoute(
            swipeRepository: context.read<SwipeRepository>(),
            swipeProvider: swipeProvider,
            coupleProvider: coupleProvider,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      swipeProvider.clearPreparedDeck();
      context.read<PreSwipeProvider>().clearDraft();
      _stopPairLifecyclePolling();
      _stopPairMatchPolling();
      _stopPairRestartPolling();
      context.read<MatchProvider>().clearMatches();
      setState(() {
        _showPairConnectionStep = false;
        _isPairRestartWaiting = false;
        _isPairRestartLoading = false;
        _pairRestartError = null;
      });

      if (decision.route == StartupRoute.newOld) {
        debugPrint('[AppFlow] startup resolved -> SessionResumeChoiceScreen');
        setState(() {
          _sessionResumeChoiceType = decision.previousMode == AppFlowMode.paired
              ? _SessionResumeChoiceType.paired
              : _SessionResumeChoiceType.solo;
        });
      } else {
        debugPrint('[AppFlow] startup resolved -> ModeSelection');
        swipeProvider.resetToModeSelection();
      }
      debugPrint(
        '[PageLoad] success page=Swipe items=${swipeProvider.deck.length}',
      );
    } catch (e) {
      debugPrint('[PageLoad] error page=Swipe error=$e');
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
    final _SessionResumeChoiceType? choiceType = _sessionResumeChoiceType;
    if (choiceType == null) {
      return;
    }
    setState(() => _pairFilterUpdateRequired = false);
    _suppressPreviousChoiceAutoOpen = false;
    _pairDeckReadyAutoLoadEnabled = true;
    setState(() => _sessionResumeChoiceType = null);
    if (choiceType == _SessionResumeChoiceType.solo) {
      _appFlow.logPreviousChoiceContinue(AppFlowMode.solo);
      debugPrint('[AppFlow] previousChoice open requested: origin=sessionResumeContinue');
      await _runSoloPreSwipeFlow();
      return;
    }
    await _continuePairedSession();
  }

  Future<void> _continuePairedSession() async {
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    swipeProvider.setPairedMode();
    swipeProvider.clearPreparedDeck();
    context.read<MatchProvider>().setActiveCouple(
          coupleProvider.currentCouple?.id,
          sessionStateVersion: coupleProvider.sessionStateVersion,
        );
    _startPairLifecyclePolling();
    _startPairMatchPolling();
    await _sendPairContinuationInvite(coupleProvider);
  }

  Future<void> _sendPairContinuationInvite(CoupleProvider coupleProvider) async {
    final invitation = await coupleProvider.createContinueAsBeforeInvite();
    if (!mounted) {
      return;
    }
    if (invitation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(coupleProvider.error ?? 'Could not invite your partner.')),
      );
      return;
    }
    _suppressPreviousChoiceAutoOpen = false;
    _pairDeckReadyAutoLoadEnabled = true;
    coupleProvider.startInvitationPolling(reason: 'session_resume_continue_pair');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your invitation was sent.')),
    );
    setState(() {});
  }

  Future<void> _confirmPairFilterChange() async {
    debugPrint('[PairFilterChange] warning opened');
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Change filters?'),
            content: const Text(
              'Changing filters will pause this deck for both of you. Your partner will also need to update their filters before you can continue swiping together.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Change filters'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !confirmed) {
      return;
    }
    _suppressPreviousChoiceAutoOpen = false;
    _pairDeckReadyAutoLoadEnabled = true;
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    context.read<SwipeProvider>().setPairedMode();
    context.read<MatchProvider>().setActiveCouple(
          coupleProvider.currentCouple?.id,
          sessionStateVersion: coupleProvider.sessionStateVersion,
        );
    _startPairLifecyclePolling();
    _startPairMatchPolling();
    final bool started = await coupleProvider.startPairFilterChange();
    if (!mounted || !started) {
      return;
    }
    await _runPreSwipeFlow(origin: _PreSwipeFlowOrigin.filtersButton, commitPairFilterChange: true);
  }

  Future<void> _showPartnerChangingFiltersDialog() async {
    final int generation = context.read<CoupleProvider>().currentCouple?.lifecycleGeneration ?? 0;
    if (!_shownPairFilterChangeInviteIds.add(generation.toString())) {
      return;
    }
    debugPrint('[PairFilterChange] partner committed event=$generation generation=$generation');
    final bool updateFilters = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
              title: const Text('Partner changed filters'),
              content: const Text(
                'Your partner updated their filters. Please update yours before you continue swiping together.',
              ),
              actions: <Widget>[
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Update filters'),
                ),
              ],
            ),
        ) ??
        false;
    if (!mounted || !updateFilters) {
      return;
    }
    setState(() => _pairFilterUpdateRequired = false);
    _suppressPreviousChoiceAutoOpen = false;
    _pairDeckReadyAutoLoadEnabled = true;
    context.read<SwipeProvider>().clearPreparedDeck();
    context.read<CoupleProvider>().consumeOpenPairFilterChange();
    await _runPreSwipeFlow(origin: _PreSwipeFlowOrigin.filtersButton);
  }

  Future<void> _startNewFromActiveSession() async {
    final _SessionResumeChoiceType? choiceType = _sessionResumeChoiceType;
    if (choiceType == null) {
      return;
    }
    final bool confirmed = await _confirmStartNew(choiceType);
    if (!confirmed || !mounted) {
      return;
    }
    await _clearActiveSessionAndShowModeSelection(choiceType);
  }

  Future<LastFilterPreset?> _loadDeckEndPreset(bool isSoloMode) async {
    final String mode = isSoloMode ? 'solo' : 'paired';
    try {
      final dynamic data = await context.read<SwipeRepository>().getLastFilterPreset(mode);
      if (!mounted) {
        return null;
      }
      final dynamic presetJson = data is Map<String, dynamic> ? data['preset'] : null;
      if (presetJson is Map) {
        final LastFilterPreset preset = LastFilterPreset.fromJson(Map<String, dynamic>.from(presetJson));
        if (kDebugMode) {
          final String? userId = context.read<AuthProvider>().currentUser?.id;
          final Couple? couple = context.read<CoupleProvider>().currentCouple;
          debugPrint('[PreviousSetup] loaded mode=$mode userId=$userId pairKey=${couple?.members.join('_')} usedAt=${preset.usedAt.toIso8601String()}');
        }
        return preset;
      }
      if (kDebugMode) {
        final Object? legacyAvailable = data is Map<String, dynamic> ? data['legacyPresetAvailable'] : false;
        debugPrint('[PreviousSetup] no preset for mode=$mode legacyAvailable=$legacyAvailable');
      }
    } catch (e) {
      debugPrint('[PreviousSetup] load failed mode=$mode error=$e');
    }
    return null;
  }

  Future<void> _restartFromInlineDeckEnd({required bool isSoloMode}) async {
    if (isSoloMode) {
      final SwipeProvider swipeProvider = context.read<SwipeProvider>();
      debugPrint('[DeckEndFilter] start mode=solo exhausted=${swipeProvider.isDeckEmpty} hasActiveSession=${swipeProvider.hasActiveSoloSession}');
      debugPrint('[DeckEndFilter] using createNewSoloSession=true');
      swipeProvider.clearPreparedDeck();
      context.read<PreSwipeProvider>().clearDraft();
      await _runSoloPreSwipeFlow();
      return;
    }

    await _requestPairRestart();
  }

  Future<void> _requestPairRestart() async {
    if (_isPairRestartLoading || _isPairRestartWaiting) {
      return;
    }
    setState(() {
      _isPairRestartLoading = true;
      _pairRestartError = null;
    });
    Map<String, dynamic>? status;
    try {
      status = await context
          .read<PendingOverlayController>()
          .run<Map<String, dynamic>?>(
            message: 'Restarting your deck...',
            operation: context.read<CoupleProvider>().requestDeckRestart,
          );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isPairRestartLoading = false;
        _pairRestartError = 'Something went wrong. Please try again.';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _isPairRestartLoading = false);
    await _handlePairRestartStatus(status);
  }

  Future<void> _pollPairRestartStatus() async {
    final Map<String, dynamic>? status = await context.read<CoupleProvider>().getDeckRestartStatus();
    if (!mounted) {
      return;
    }
    await _handlePairRestartStatus(status);
  }

  Future<void> _handlePairRestartStatus(Map<String, dynamic>? status) async {
    if (status == null) {
      setState(() => _pairRestartError = context.read<CoupleProvider>().error ?? 'Could not restart the pair session.');
      return;
    }
    if (status['allRequested'] == true || status['status'] == 'ready') {
      _suppressPreviousChoiceAutoOpen = false;
      _pairDeckReadyAutoLoadEnabled = true;
      _stopPairRestartPolling();
      context.read<SwipeProvider>().clearPreparedDeck();
      context.read<PreSwipeProvider>().clearDraft();
      setState(() {
        _isPairRestartWaiting = false;
        _pairRestartError = null;
      });
      debugPrint('[AppFlow] previousChoice open requested: origin=${_PreSwipeFlowOrigin.deckRestart.logName}');
      await _runPreSwipeFlow(origin: _PreSwipeFlowOrigin.deckRestart);
      return;
    }
    setState(() {
      _isPairRestartWaiting = true;
      _pairRestartError = null;
    });
    _startPairRestartPolling();
  }

  void _startPairRestartPolling() {
    _pairRestartPollingTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollPairRestartStatus());
    });
  }

  void _stopPairRestartPolling() {
    _pairRestartPollingTimer?.cancel();
    _pairRestartPollingTimer = null;
  }

  Future<bool> _confirmStartNew(_SessionResumeChoiceType choiceType) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Start new session?'),
            content: Text(
              choiceType == _SessionResumeChoiceType.solo
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

  Future<void> _clearActiveSessionAndShowModeSelection(_SessionResumeChoiceType choiceType) async {
    final SwipeProvider swipeProvider = context.read<SwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    if (choiceType == _SessionResumeChoiceType.solo) {
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
    _stopPairRestartPolling();
    context.read<MatchProvider>().clearMatches();
    setState(() {
      _sessionResumeChoiceType = null;
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
      _stopPairLifecyclePolling();
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

  Future<void> _runPreSwipeFlow({required _PreSwipeFlowOrigin origin, bool commitPairFilterChange = false}) async {
    debugPrint('[AppFlow] _runPreSwipeFlow requested: origin=${origin.logName}');
    debugPrint('[PairFlow] previousChoice opened origin=${origin.logName} session=${context.read<CoupleProvider>().currentCouple?.id ?? 'none'} generation=${context.read<CoupleProvider>().currentCouple?.lifecycleGeneration ?? 0}');
    if (_isOpeningPreSwipe) {
      return;
    }

    _isOpeningPreSwipe = true;
    _pairDeckReadyAutoLoadEnabled = true;
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

    final PreparedPoolResult? result = await Navigator.of(context).push<PreparedPoolResult>(
      MaterialPageRoute<PreparedPoolResult>(
        fullscreenDialog: true,
        builder: (_) => PreSwipeFilterScreen(mode: 'paired', commitPairFilterChange: commitPairFilterChange),
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
      if (!swipeProvider.isSoloMode) {
        if (coupleProvider.bothConfirmed) {
          await _loadCanonicalPairDeckAndShowSwipe(reason: 'pre_swipe_closed_after_pair_ready');
        } else {
          debugPrint('[PairDeck] pre-swipe closed before both confirmed; staying in waiting state');
        }
      } else if (!swipeProvider.hasPreparedDeck && (!coupleProvider.hasCouple || coupleProvider.bothConfirmed)) {
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
      final CoupleProvider coupleProvider = _coupleProvider ?? context.read<CoupleProvider>();
      if (!swipeProvider.isSoloMode) {
        if (coupleProvider.bothConfirmed) {
          await _loadCanonicalPairDeckAndShowSwipe(reason: 'empty_pre_swipe_result_after_pair_ready');
        } else {
          debugPrint('[PairDeck] empty pre-swipe result before both confirmed; no local Pair deck applied');
        }
      } else {
        swipeProvider.applyPreparedDeck(<Dish>[]);
      }
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
    debugPrint('[PairDeck] canonical deck loaded session=${(_coupleProvider ?? context.read<CoupleProvider>()).currentCouple?.id ?? 'none'} generation=${result.preparedDeckMeta?.filtersHash ?? (_coupleProvider ?? context.read<CoupleProvider>()).currentCouple?.lifecycleGeneration ?? 0} size=${result.dishes.length}');
    _clearStalePairDeckSetupState(reason: 'pre_swipe_result_ready');
    _startPairLifecyclePolling();
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
          _appFlow.logModeSelection(AppFlowMode.solo);
          _runSoloPreSwipeFlow();
        },
      ),
    );
  }


  void _startPairLifecyclePolling() {
    _pairLifecyclePollingTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollPairLifecycle());
    });
    unawaited(_pollPairLifecycle());
  }

  void _stopPairLifecyclePolling() {
    _pairLifecyclePollingTimer?.cancel();
    _pairLifecyclePollingTimer = null;
  }

  Future<void> _pollPairLifecycle() async {
    if (!mounted || context.read<SwipeProvider>().isSoloMode) {
      return;
    }
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    await coupleProvider.loadCouple(force: true);
    if (!mounted) {
      return;
    }
    if (coupleProvider.needsPairResync) {
      debugPrint('[PairLifecycle] poll -> needs_resync detected');
      await _handlePairNeedsResync();
    }
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
    _swipeStackKey.currentState?.resetInteractionState();
  }


  Future<void> _handleSwipe(SwipeDirection direction) async {
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

    await swipeAction.then((dynamic result) {
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
          context.read<NavBadgeAnimationController>().showSoloMatchesPlusOne();
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: TweenAnimationBuilder<double>(
          //       tween: Tween<double>(begin: 0.92, end: 1),
          //       duration: AppMotion.fast,
          //       curve: AppMotion.curve,
          //       builder: (BuildContext context, double scale, Widget? child) {
          //         return Opacity(
          //           opacity: scale.clamp(0.0, 1.0),
          //           child: Transform.scale(
          //             scale: scale,
          //             alignment: Alignment.centerLeft,
          //             child: child,
          //           ),
          //         );
          //       },
          //       child: const Row(
          //         children: <Widget>[
          //           Icon(Icons.favorite, color: Colors.white, size: 18),
          //           SizedBox(width: 8),
          //           Text('Saved to Matches'),
          //         ],
          //       ),
          //     ),
          //     duration: const Duration(milliseconds: 1400),
          //     behavior: SnackBarBehavior.floating,
          //   ),
          // );
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
      final SwipeableStackState? swipeStackState = _swipeStackKey.currentState;
      debugPrint('[ButtonSwipe] like tapped currentState=${swipeStackState != null}');
      if (swipeStackState != null) {
        await swipeStackState.swipeRightFromButton();
      }
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
      final SwipeableStackState? swipeStackState = _swipeStackKey.currentState;
      debugPrint('[ButtonSwipe] dislike tapped currentState=${swipeStackState != null}');
      if (swipeStackState != null) {
        await swipeStackState.swipeLeftFromButton();
      }
    } finally {
      _isCardActionInProgress = false;
    }
  }

  Future<void> _handleBack(SwipeProvider provider) async {
    if (_isCardActionInProgress || !provider.canUndo) {
      return;
    }
    _isCardActionInProgress = true;
    final String? undoDishId = provider.lastSwipedDish?.id;
    final SwipeDirection? undoDirection = switch (provider.lastSwipedDirection) {
      'like' => SwipeDirection.right,
      'dislike' => SwipeDirection.left,
      _ => null,
    };
    try {
      await provider.undo();
      if (undoDishId != null &&
          undoDirection != null &&
          provider.currentDish?.id == undoDishId) {
        final SwipeableStackState? swipeStackState =
            _swipeStackKey.currentState;
        debugPrint(
          '[UndoAnim] requested hasCurrentState=${swipeStackState != null} direction=${undoDirection.name}',
        );
        await swipeStackState?.playUndoReturnAnimation(
          direction: undoDirection,
        );
      }
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
    final bool showSessionResumeChoice = !_isLoadingInitialSession && _sessionResumeChoiceType != null;
    final bool showModeSelection = !_isLoadingInitialSession &&
        _sessionResumeChoiceType == null &&
        !hasCouple &&
        !isSoloMode &&
        deckIsEmpty &&
        !_showPairConnectionStep;
    final bool showPairConnection = !_isLoadingInitialSession &&
        _sessionResumeChoiceType == null &&
        (_showPairConnectionStep || (hasCouple && !hasPartner && !isSoloMode));
    final bool showHeaderActions = hasCurrentDeckCard && !showSessionResumeChoice && !showModeSelection && !showPairConnection && !_isOpeningPreSwipe;
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
                  FoodMatchRipple(
                    onTap: () => _showSessionSettingsSheet(context),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                    rippleColor: colors.neutralRipple,
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
                  FoodMatchRipple(
                    onTap: () {
                      _appFlow.logFiltersButton();
                      _suppressPreviousChoiceAutoOpen = false;
                      if (context.read<SwipeProvider>().isSoloMode) {
                        _runSoloPreSwipeFlow(intent: PreSwipeFilterIntent.updateActiveSoloSession);
                      } else {
                        _pairDeckReadyAutoLoadEnabled = true;
                        unawaited(_confirmPairFilterChange());
                      }
                    },
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                    rippleColor: colors.primaryRipple,
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
                    final CoupleProvider inviteCoupleProvider = context.watch<CoupleProvider>();
                    _syncPairFilterChangeDialogMarkers(inviteCoupleProvider);
                    if (inviteCoupleProvider.needsPairFilterChange &&
                        !provider.isSoloMode &&
                        _sessionResumeChoiceType == null &&
                        !_suppressPreviousChoiceAutoOpen &&
                        !_isOpeningPreSwipe) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          unawaited(_showPartnerChangingFiltersDialog());
                        }
                      });
                    }
                    if (inviteCoupleProvider.needsPairResync && !_isOpeningPreSwipe) {
                      final int versionAtSchedule = context.read<AuthProvider>().authBoundaryVersion;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (context.read<AuthProvider>().authBoundaryVersion != versionAtSchedule) {
                          return;
                        }
                        unawaited(_handlePairNeedsResync());
                      });
                    }
                    if (inviteCoupleProvider.shouldOpenPreviousChoiceAfterInvite && !_isOpeningPreSwipe) {
                      final int versionAtSchedule = context.read<AuthProvider>().authBoundaryVersion;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (context.read<AuthProvider>().authBoundaryVersion != versionAtSchedule) {
                          return;
                        }
                        final CoupleProvider coupleProvider = context.read<CoupleProvider>();
                        if (_suppressPreviousChoiceAutoOpen &&
                            !coupleProvider.previousChoiceAfterInviteWasUserAccepted) {
                          coupleProvider.consumeOpenPreviousChoiceAfterInvite();
                          debugPrint('[AppFlow] authBoundary -> blocked previous choice auto-open');
                          return;
                        }
                        if (coupleProvider.consumeOpenPreviousChoiceAfterInvite()) {
                          debugPrint('[AppFlow] previousChoice open requested: origin=${_PreSwipeFlowOrigin.pairInvitationAccepted.logName}');
                          _runPreSwipeFlow(origin: _PreSwipeFlowOrigin.pairInvitationAccepted);
                        }
                      });
                    }

                    if (_isLoadingInitialSession) {
                      return const ShimmerCard();
                    }

                    if (_initialSessionError != null) {
                      return ErrorState(
                        message: _initialSessionError!,
                        onRetry: _loadExistingBackendDeckOrStart,
                      );
                    }

                    final bool shouldLoadCanonicalPairDeck =
                        !provider.isSoloMode &&
                        hasCouple &&
                        hasPartner &&
                        bothConfirmed &&
                        (_pairDeckReadyAutoLoadEnabled || _sessionResumeChoiceType == null) &&
                        provider.deck.isEmpty &&
                        (_lastPairDeckReadyLoadAttemptAt == null ||
                            DateTime.now().difference(_lastPairDeckReadyLoadAttemptAt!) > const Duration(seconds: 2));
                    if (shouldLoadCanonicalPairDeck) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          unawaited(_loadCanonicalPairDeckAndShowSwipe(reason: 'both_confirmed_waiting_poll'));
                        }
                      });
                      return const ShimmerCard();
                    }

                    if (showSessionResumeChoice) {
                      final _SessionResumeChoiceType choiceType = _sessionResumeChoiceType!;
                      final bool soloContext = choiceType == _SessionResumeChoiceType.solo;
                      final CoupleMemberProfile? partner = resolvePartnerProfile(
                        couple: context.read<CoupleProvider>().currentCouple,
                        currentUserId: context.read<AuthProvider>().currentUser?.id,
                      );
                      return SessionResumeChoiceScreen(
                        isSoloMode: soloContext,
                        partner: partner,
                        onLoadPreviousSetup: () => _loadDeckEndPreset(soloContext),
                        onUsePreviousFilter: (_) => _continueActiveSession(),
                        onStartNew: _startNewFromActiveSession,
                      );
                    }

                    if (showModeSelection) {
                      return SwipeModeSelectionScreen(
                        onSolo: () {
                          _appFlow.logModeSelection(AppFlowMode.solo);
                          _suppressPreviousChoiceAutoOpen = false;
                          setState(() => _showPairConnectionStep = false);
                          _runSoloPreSwipeFlow();
                        },
                        onPairUp: () {
                          _appFlow.logModeSelection(AppFlowMode.paired);
                          _suppressPreviousChoiceAutoOpen = false;
                          _pairDeckReadyAutoLoadEnabled = true;
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
                        onBack: () {
                          _appFlow.logCloseX();
                          context.read<SwipeProvider>().resetToModeSelection();
                          setState(() => _showPairConnectionStep = false);
                        },
                        onPairConnected: () async {
                          if (!mounted) return;
                          _suppressPreviousChoiceAutoOpen = false;
                          _pairDeckReadyAutoLoadEnabled = true;
                          setState(() => _showPairConnectionStep = false);
                          _appFlow.logInviteAccepted();
                          debugPrint('[AppFlow] previousChoice open requested: origin=${_PreSwipeFlowOrigin.pairConnectionReady.logName}');
                          await _runPreSwipeFlow(origin: _PreSwipeFlowOrigin.pairConnectionReady);
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
                        onButtonPressed: () {
                          _appFlow.logFiltersButton();
                          _suppressPreviousChoiceAutoOpen = false;
                          if (provider.isSoloMode) {
                            _runSoloPreSwipeFlow(intent: PreSwipeFilterIntent.updateActiveSoloSession);
                          } else {
                            _pairDeckReadyAutoLoadEnabled = true;
                            unawaited(_confirmPairFilterChange());
                          }
                        },
                      );
                    }

                    final outgoingInvite = context.watch<CoupleProvider>().outgoingContinuationInvite;
                    if (outgoingInvite != null && outgoingInvite.isPending && !provider.isSoloMode) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.hourglass_empty, size: 80),
                              const SizedBox(height: 16),
                              const Text('Waiting for partner', textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              const Text(
                                'Your partner needs to choose their filters before the shared deck can be prepared.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () async {
                                  final CoupleProvider coupleProvider = context.read<CoupleProvider>();
                                  final SwipeProvider swipeProvider = context.read<SwipeProvider>();
                                  await coupleProvider.loadCouple(force: true);
                                  await coupleProvider.refreshInvitations();
                                  if (!mounted) return;
                                  if (!coupleProvider.hasCouple) {
                                    swipeProvider.resetToModeSelection();
                                  }
                                  setState(() {});
                                },
                                child: const Text('Refresh'),
                              ),
                              TextButton(
                                onPressed: () => _clearActiveSessionAndShowModeSelection(_SessionResumeChoiceType.paired),
                                child: const Text('Start new session'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }


                    if (_pairFilterUpdateRequired && !provider.isSoloMode) {
                      return EmptyState(
                        icon: Icons.tune,
                        title: 'Update filters required',
                        subtitle: 'Your partner changed their filters. Update yours to continue swiping together.',
                        buttonText: 'Update filters',
                        onButtonPressed: () {
                          setState(() => _pairFilterUpdateRequired = false);
                          context.read<SwipeProvider>().clearPreparedDeck();
                          context.read<CoupleProvider>().consumeOpenPairFilterChange();
                          _runPreSwipeFlow(origin: _PreSwipeFlowOrigin.filtersButton);
                        },
                      );
                    }

                    if (_isPairDeckReadyLoading && !provider.isSoloMode) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const FoodMatchLoader(size: 150),
                              const SizedBox(height: 16),
                              const Text('Preparing your shared deck', textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              const Text(
                                'We’re matching your filters. This may take a moment.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (provider.isLoading) {
                      return const ShimmerCard();
                    }

                    if (provider.error != null) {
                      return ErrorState(
                        message: provider.error!,
                        onRetry: provider.isSoloMode
                            ? provider.loadDeck
                            : () => _loadCanonicalPairDeckAndShowSwipe(reason: 'pair_deck_error_retry'),
                      );
                    }

                    _preloadVisibleDishImages(provider);

                    final bool allowDeckEnd = provider.deck.isNotEmpty &&
                        provider.isDeckEmpty &&
                        !_isPairDeckReadyLoading &&
                        !_isOpeningPreSwipe &&
                        _sessionResumeChoiceType == null &&
                        !(hasCouple && hasPartner && !bothConfirmed && !provider.isSoloMode) &&
                        provider.error == null;
                    debugPrint('[DeckEnd] render check mode=${provider.currentSwipeMode} deckSize=${provider.deck.length} index=${provider.currentIndex} loaded=${provider.deck.isNotEmpty} exhausted=${provider.isDeckEmpty} allowed=$allowDeckEnd reason=${allowDeckEnd ? 'deck_exhausted' : 'not_current_exhausted_deck'}');
                    if (allowDeckEnd) {
                      final bool soloContext = provider.isSoloMode;
                      return InlineDeckEndRestartCard(
                        isWaitingForPartner: !soloContext && _isPairRestartWaiting,
                        isLoading: !soloContext && _isPairRestartLoading,
                        errorMessage: _pairRestartError,
                        onRestart: () => _restartFromInlineDeckEnd(isSoloMode: soloContext),
                        onViewMatches: () => context.go('/matches'),
                      );
                    }
                    if (provider.deck.isEmpty) {
                      return const ShimmerCard();
                    }

                    return SwipeableStack(
                      key: _swipeStackKey,
                      itemCount: provider.deck.length - provider.currentIndex,
                      canSwipe: !provider.isLoading &&
                          !provider.isSendingSwipe &&
                          !_isCardActionInProgress,
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
                        unawaited(_handleSwipe(direction));
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
