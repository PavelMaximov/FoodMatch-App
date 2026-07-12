import 'package:flutter/foundation.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../../../core/animations/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/models/user_profile.dart';
import '../../../../data/repositories/swipe_repository.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../../matches/logic/match_provider.dart';
import '../../logic/filter_scoring_service.dart';
import '../../logic/pre_swipe_provider.dart';
import '../../logic/swipe_provider.dart';
import 'previous_filter_choice_screen.dart';

enum PreSwipeFilterIntent {
  createNewSession,
  updateActiveSoloSession,
}

class PreSwipeFilterScreen extends StatefulWidget {
  const PreSwipeFilterScreen({
    super.key,
    this.mode = 'paired',
    this.intent = PreSwipeFilterIntent.createNewSession,
  });

  final String mode;
  final PreSwipeFilterIntent intent;

  @override
  State<PreSwipeFilterScreen> createState() => _PreSwipeFilterScreenState();
}

class _PreSwipeFilterScreenState extends State<PreSwipeFilterScreen> {
  static const double _chipRadius = 15;
  static const double _chipFontSize = 17;

  int _step = 1;
  bool _showIntro = false;
  bool _showPreviousChoice = false;
  bool _loading = false;
  bool _waitingForPartner = false;
  bool _isPreparingSharedDeck = false;
  bool _hasStartedPrepareAfterBothConfirmed = false;
  bool _isApplyingFilters = false;
  bool _isGoingBack = false;
  String? _pendingUserId;
  LastFilterPreset? _lastFilterPreset;
  late final CoupleProvider _coupleProvider;

  final Set<String> _cuisines = <String>{};
  final Set<String> _moods = <String>{};
  final Set<String> _blocked = <String>{};
  final Set<String> _diet = <String>{};
  Set<String> _favoriteCuisines = <String>{};
  List<Dish> _allDishes = <Dish>[];

  List<String> _cuisineOptions = <String>['Any'];

  final Map<String, Future<bool>> _filterIconAssetAvailability = <String, Future<bool>>{};

  static const Map<String, String> _filterIconNameOverrides = <String, String>{
    'Any': 'any',
    'Comfort': 'mood_comfort',
    'Healthy': 'mood_healthy',
    'Exotic': 'mood_exotic',
    'Indulgent': 'mood_indulgent',
    'Quick': 'mood_quick',
    'Light': 'mood_light',
    'Vegetarian': 'diet_vegetarian',
    'Vegan': 'diet_vegan',
    'Halal': 'diet_halal',
    'no_meat': 'no_meat',
    'no_dairy': 'no_dairy',
    'no_gluten': 'no_gluten',
    'no_nuts': 'no_nuts',
    'no_seafood': 'no_seafood',
  };

  Future<bool> _hasFilterIconAsset(String assetPath) =>
      _filterIconAssetAvailability.putIfAbsent(
        assetPath,
        () async {
          try {
            await rootBundle.load(assetPath);
            return true;
          } catch (_) {
            if (kDebugMode) {
              debugPrint('[PreSwipeFilterScreen] Missing filter SVG asset: $assetPath');
            }
            return false;
          }
        },
      );

  String _filterIconAssetPath(String option) {
    final String normalized = option.trim();
    final String fileName = _filterIconNameOverrides[normalized] ??
        normalized.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

    return 'assets/icons/filters/$fileName.svg';
  }

  static const List<String> _moodOptions = <String>[
    'Comfort',
    'Healthy',
    'Exotic',
    'Indulgent',
    'Quick',
    'Light',
  ];

  static const List<String> _exceptionOptions = <String>[
    'no_meat',
    'no_dairy',
    'no_gluten',
    'no_nuts',
    'no_seafood',
  ];

  static const List<String> _dietOptions = <String>['Any', 'Vegetarian', 'Vegan', 'Halal'];

  @override
  void initState() {
    super.initState();
    _coupleProvider = context.read<CoupleProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final String? userId = context.read<AuthProvider>().currentUser?.id;
      UserProfile? profile;
      if (userId != null) {
        profile = await context.read<PreSwipeProvider>().loadProfile(userId);
        if (mounted) {
          setState(() {
            _favoriteCuisines = profile!.favoriteCuisines.toSet();
            _showIntro = profile.preSwipeFilterIntroSeenAt == null;
          });
        }
      }
      if (!mounted) {
        return;
      }

      if (widget.mode == 'paired') {
        _coupleProvider.startFilterStatePolling(reason: 'pre_swipe_init');
        await _coupleProvider.refreshFilterState(reason: 'pre_swipe_init');
      }
      if (!mounted) {
        return;
      }
      final LastFilterPreset? backendPreset = await _loadBackendLastFilterPreset();
      if (mounted) {
        setState(() => _lastFilterPreset = backendPreset);
      }
      if (!mounted) {
        return;
      }
      if (widget.mode == 'paired' && _coupleProvider.isMyChoicesConfirmed && !_coupleProvider.bothConfirmed) {
        debugPrint('[PreSwipe] waiting for partner filters');
        setState(() {
          _showIntro = false;
          _waitingForPartner = true;
          _pendingUserId = userId;
        });
        _startWaitingPolling();
        return;
      }
      final PreSwipeProvider preSwipeProvider = context.read<PreSwipeProvider>();
      final List<Dish> dishes = await preSwipeProvider.loadDishes();
      final List<String> cuisines = await preSwipeProvider.loadCuisineOptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _allDishes = dishes;
        _cuisineOptions = cuisines;
        if (!_showIntro && _lastFilterPreset != null && !_coupleProvider.isMyChoicesConfirmed) {
          _showPreviousChoice = true;
        }
      });
    });
  }


  Future<LastFilterPreset?> _loadBackendLastFilterPreset() async {
    try {
      final dynamic data = await context.read<SwipeRepository>().getLastFilterPreset(widget.mode);
      final dynamic preset = data is Map<String, dynamic> ? data['preset'] : null;
      if (preset is Map) {
        return LastFilterPreset.fromJson(Map<String, dynamic>.from(preset));
      }
    } catch (e) {
      debugPrint('[PreSwipe] backend last filter load failed $e');
    }
    return null;
  }

  Future<void> _saveBackendLastFilterPreset(int matchedLastTime) async {
    try {
      await context.read<SwipeRepository>().saveLastFilterPreset(
            mode: widget.mode,
            cuisines: _cuisines.toList(),
            moods: _moods.toList(),
            diet: _diet.toList(),
            exclusions: _blocked.toList(),
            matchedLastTime: matchedLastTime,
          );
    } catch (e) {
      debugPrint('[PreSwipe] backend last filter save failed $e');
    }
    _lastFilterPreset = LastFilterPreset(
      cuisines: _cuisines.toList(),
      moods: _moods.toList(),
      diet: _diet.toList(),
      exclusions: _blocked.toList(),
      matchedLastTime: matchedLastTime,
      usedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    if (widget.mode == 'paired') {
      _coupleProvider.stopFilterStatePolling(reason: 'pre_swipe_dispose');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return PreSwipeIntroScreen(
        onClose: () => Navigator.of(context).pop(),
        onCustomize: _continueFromIntro,
      );
    }

    if (_showPreviousChoice && _lastFilterPreset != null) {
      return PreviousFilterChoiceScreen(
        preset: _lastFilterPreset!,
        onUsePreset: _usePreviousPreset,
        onChangeFilters: _startFreshFilters,
        onClose: () => Navigator.of(context).maybePop(),
      );
    }

    if (_waitingForPartner) {
      return Consumer<CoupleProvider>(
        builder: (BuildContext context, CoupleProvider coupleProvider, _) {
          _schedulePrepareIfBothConfirmed(coupleProvider);
          return _buildWaitingForPartnerScreen();
        },
      );
    }

    return Scaffold(
      backgroundColor: context.fmColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('Step $_step / 3', style: GoogleFonts.nunito(fontSize: 16)),
                  IconButton(
                    onPressed: _loading ? null : () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close, color: context.fmColors.textSecondary),
                    tooltip: 'Close filters',
                  ),
                ],
              ),
              Text(
                _title,
                style: AppTextStyles.pageTitle.copyWith(color: context.fmColors.textPrimary),
              ),
              const SizedBox(height: 10),
              Text(_subtitle, style: GoogleFonts.nunito(fontSize: 18, color: context.fmColors.textSecondary)),
              const SizedBox(height: 24),
              Expanded(
                child: PageTransitionSwitcher(
                  duration: AppMotion.durationFor(context, AppMotion.normal),
                  reverse: _isGoingBack,
                  transitionBuilder: (
                    Widget child,
                    Animation<double> animation,
                    Animation<double> secondaryAnimation,
                  ) {
                    return SharedAxisTransition(
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      transitionType: SharedAxisTransitionType.horizontal,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<int>(_step),
                    child: _buildStepContent(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Consumer<CoupleProvider>(
                builder: (BuildContext context, CoupleProvider coupleProvider, _) {
                  return _FilterBottomPanel(
                    cuisines: _cuisines.toList(),
                    availability: context.read<PreSwipeProvider>().buildAvailabilitySummary(
                          allDishes: _allDishes,
                          cuisines: _cuisines.toList(),
                          moods: _moods.toList(),
                          blocked: _blocked.toList(),
                          diet: _diet.toList(),
                          partnerChoices: widget.mode == 'paired' ? coupleProvider.partnerChoices : null,
                        ),
                    isLoading: _loading,
                    canGoBack: _step > 1,
                    primaryLabel: _step == 3 ? 'Confirm' : 'Continue',
                    onBack: _step == 1
                        ? null
                        : () => setState(() {
                              _isGoingBack = true;
                              _step--;
                            }),
                    onSkip: _loading ? null : _skip,
                    onContinue: _loading ? null : _next,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title => _step == 1
      ? 'Cuisine'
      : _step == 2
          ? 'Mood'
          : 'Exclusions';

  String get _subtitle => _step == 1
      ? 'Pick the cuisines you want to see.'
      : _step == 2
          ? "We'll prioritize dishes with this vibe."
          : "Choose ingredients you want to avoid. We'll remove dishes that contain them.";

  Widget _buildStepContent() {
    if (_step == 1) {
      return SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: _buildChipGrid(
          options: _cuisineOptions,
          selected: _cuisines,
          onTap: _toggleCuisine,
          chipStates: context.read<PreSwipeProvider>().buildCuisineChipStates(_cuisineOptions, _allDishes),
          anyWhenEmpty: true,
          ),
        ),
      );
    }

    if (_step == 2) {
      return SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: _buildChipGrid(
          options: _moodOptions,
          selected: _moods,
          onTap: (String value) {
            setState(() {
              if (_moods.contains(value)) {
                _moods.remove(value);
              } else if (_moods.length < 3) {
                _moods.add(value);
              }
            });
          },
          chipStates: context.read<PreSwipeProvider>().buildMoodChipStates(
                options: _moodOptions,
                allDishes: _allDishes,
                selectedCuisines: _cuisines.toList(),
              ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildChipGrid(
            options: _dietOptions,
            selected: _diet,
            onTap: _toggleDiet,
            anyWhenEmpty: true,
          ),
          const SizedBox(height: 16),
          _buildChipGrid(
            options: _exceptionOptions,
            selected: _blocked,
            onTap: (String value) {
              setState(() {
                if (_blocked.contains(value)) {
                  _blocked.remove(value);
                } else {
                  _blocked.add(value);
                }
              });
            },
            chipStates: context.read<PreSwipeProvider>().buildExceptionChipStates(
                  options: _exceptionOptions,
                  allDishes: _allDishes,
                  selectedCuisines: _cuisines.toList(),
                ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildChipGrid({
    required List<String> options,
    required Set<String> selected,
    required void Function(String) onTap,
    bool anyWhenEmpty = false,
    List<FilterChipState> chipStates = const <FilterChipState>[],
  }) {
    return Wrap(
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      spacing: 10,
      runSpacing: 10,
      children: options.map((String option) {
        final String assetPath = _filterIconAssetPath(option);
        final FilterChipState? chipState = _chipStateFor(option, chipStates);
        final bool isAny = option == 'Any';
        final bool isSelected = anyWhenEmpty && isAny ? selected.isEmpty : selected.contains(option);
        final bool isEnabled = chipState?.enabled ?? true;
        final bool highlighted = options == _cuisineOptions && !_cuisines.contains(option) && _favoriteCuisines.contains(option);

        return _FilterOptionChip(
          option: option,
          label: _chipLabel(option),
          assetPath: assetPath,
          assetExists: _hasFilterIconAsset(assetPath),
          selected: isSelected,
          enabled: isEnabled,
          highlighted: highlighted,
          onTap: () => onTap(option),
        );
      }).toList(),
    );
  }

  FilterChipState? _chipStateFor(String option, List<FilterChipState> chipStates) {
    for (final FilterChipState chipState in chipStates) {
      if (chipState.value == option) {
        return chipState;
      }
    }
    return null;
  }

  String _chipLabel(String option) {
    return _displayLabel(option);
  }

  String _displayLabel(String value) {
    switch (value) {
      case 'no_meat':
        return 'No meat';
      case 'no_dairy':
        return 'No dairy';
      case 'no_gluten':
        return 'No gluten';
      case 'no_nuts':
        return 'No nuts';
      case 'no_seafood':
        return 'No seafood';
      default:
        return formatOptionLabel(value);
    }
  }

  void _toggleCuisine(String value) {
    setState(() {
      if (value == 'Any') {
        _cuisines.clear();
        return;
      }

      if (_cuisines.contains(value)) {
        _cuisines.remove(value);
      } else if (_cuisines.length < 3) {
        _cuisines.add(value);
      }
    });
  }

  void _toggleDiet(String value) {
    setState(() {
      if (value == 'Any') {
        _diet.clear();
        return;
      }
      if (_diet.contains(value)) {
        _diet.remove(value);
      } else {
        _diet.add(value);
      }
    });
  }

  Future<void> _continueFromIntro() async {
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) {
      await context.read<PreSwipeProvider>().markIntroSeen(userId);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _showIntro = false;
      _showPreviousChoice = _lastFilterPreset != null && !_coupleProvider.isMyChoicesConfirmed;
    });
  }

  void _startFreshFilters() {
    setState(() {
      _showPreviousChoice = false;
      _step = 1;
      _cuisines.clear();
      _moods.clear();
      _blocked.clear();
      _diet.clear();
    });
  }

  Future<void> _usePreviousPreset() async {
    final LastFilterPreset? preset = _lastFilterPreset;
    if (preset == null) {
      _startFreshFilters();
      return;
    }
    setState(() {
      _showPreviousChoice = false;
      _cuisines
        ..clear()
        ..addAll(preset.cuisines);
      _moods
        ..clear()
        ..addAll(preset.moods);
      _blocked
        ..clear()
        ..addAll(preset.exclusions);
      _diet
        ..clear()
        ..addAll(preset.diet);
    });
    await _confirmCurrentFilters();
  }

  Future<void> _next() async {
    if (_step < 3) {
      setState(() {
        _isGoingBack = false;
        _step++;
      });
      return;
    }
    await _confirmCurrentFilters();
  }

  Future<void> _confirmCurrentFilters() async {
    if (_isApplyingFilters) {
      return;
    }
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      Navigator.pop(context);
      return;
    }
    final PreSwipeProvider preSwipeProvider = context.read<PreSwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    final int matchedLastTime = preSwipeProvider.countMatchingDishes(
      allDishes: _allDishes,
      cuisines: _cuisines.toList(),
      moods: _moods.toList(),
      blocked: _blocked.toList(),
      diet: _diet.toList(),
      partnerChoices: widget.mode == 'paired' ? coupleProvider.partnerChoices : null,
    );

    setState(() {
      _loading = true;
      _isApplyingFilters = true;
    });
    if (widget.mode == 'solo') {
      final SwipeProvider swipeProvider = context.read<SwipeProvider>();
      final bool shouldUpdateActiveSession = widget.intent == PreSwipeFilterIntent.updateActiveSoloSession || swipeProvider.activeSoloSessionId != null;
      final bool ready = shouldUpdateActiveSession
          ? await swipeProvider.rebuildActiveSoloSessionFilters(
              cuisines: _cuisines.toList(),
              moods: _moods.toList(),
              blocked: _blocked.toList(),
              diet: _diet.toList(),
            )
          : await swipeProvider.createSoloSession(
              cuisines: _cuisines.toList(),
              moods: _moods.toList(),
              blocked: _blocked.toList(),
              diet: _diet.toList(),
            );
      if (!mounted) return;
      if (ready) {
        context.read<MatchProvider>().setSoloSession(swipeProvider.activeSoloSessionId);
        await _saveBackendLastFilterPreset(matchedLastTime);
        if (!mounted) return;
        Navigator.pop(context, PreparedPoolResult(dishes: swipeProvider.deck, seenDishIds: <String>{}, usedFallback: false, relaxed: false, messages: const <String>[]));
      } else {
        setState(() {
          _loading = false;
          _isApplyingFilters = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(swipeProvider.error ?? 'Could not update filters. You can go back to your current deck.')));
      }
      return;
    }
    await preSwipeProvider.saveAndConfirmChoices(
      userId: userId,
      coupleProvider: coupleProvider,
      cuisines: _cuisines.toList(),
      moods: _moods.toList(),
      blocked: _blocked.toList(),
      diet: _diet.toList(),
    );
    await _saveBackendLastFilterPreset(matchedLastTime);

    if (!mounted) {
      return;
    }
    await coupleProvider.refreshFilterState(reason: 'after_confirm_filters');

    if (!mounted) {
      return;
    }

    if (!coupleProvider.bothConfirmed) {
      debugPrint('[PreSwipe] waiting for partner filters');
      setState(() {
        _loading = false;
        _isApplyingFilters = false;
        _waitingForPartner = true;
        _pendingUserId = userId;
        _hasStartedPrepareAfterBothConfirmed = false;
      });
      _startWaitingPolling();
      return;
    }

    await _prepareSharedDeck(userId);
  }


  Widget _buildWaitingForPartnerScreen() {
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    final bool needsSession = !coupleProvider.hasCouple;
    final bool waitingForJoin = coupleProvider.hasCouple && !coupleProvider.hasPartner;
    final bool preparingDeck = _isPreparingSharedDeck;
    final String title = needsSession
        ? 'Create or join a session'
        : waitingForJoin
            ? 'Waiting for your partner to join'
            : preparingDeck
                ? 'Preparing your shared deck'
                : 'Waiting for partner choices';
    final String description = coupleProvider.syncMessage ??
        (needsSession
            ? 'Start a couple session to swipe together.'
            : waitingForJoin
                ? 'Share your invite code. We’ll start when your partner joins.'
                : preparingDeck
                    ? 'Both filter sets are ready. We’re preparing your shared deck now.'
                    : 'Your choices are saved. We’ll start swiping when your partner finishes their filters.');

    return Scaffold(
      backgroundColor: context.fmColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            children: <Widget>[
              const Spacer(flex: 1),
              Image.asset(
                'assets/media/pre_swipe_intro.png',
                height: 190,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    fontWeight: FontWeight.w700,
                    fontSize: 34,
                    color: context.fmColors.textPrimary,
                    height: 1.12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: context.fmColors.textSecondary,
                    height: 1.38,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Lottie.asset(
                'assets/animations/waiting.json',
                width: 84,
                height: 84,
                fit: BoxFit.contain,
                repeat: true,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isPreparingSharedDeck ? null : () => Navigator.of(context).pop(),
                child: const Text('Back to session settings'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }


  void _startWaitingPolling() {
    _coupleProvider.startFilterStatePolling(reason: 'waiting_partner_choices');
  }

  void _schedulePrepareIfBothConfirmed(CoupleProvider coupleProvider) {
    if (!coupleProvider.bothConfirmed || _isPreparingSharedDeck || _hasStartedPrepareAfterBothConfirmed) {
      return;
    }
    final String? userId = _pendingUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    _hasStartedPrepareAfterBothConfirmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_waitingForPartner || _isPreparingSharedDeck) {
        return;
      }
      debugPrint('[PreSwipe] both confirmed, preparing shared deck');
      _prepareSharedDeck(userId);
    });
  }

  Future<void> _prepareSharedDeck(String userId) async {
    if (_isPreparingSharedDeck) {
      return;
    }
    final CoupleProvider currentCoupleProvider = context.read<CoupleProvider>();
    if (!currentCoupleProvider.bothConfirmed) {
      debugPrint('[Deck] prepare skipped: filters not ready');
      setState(() => _waitingForPartner = true);
      _startWaitingPolling();
      return;
    }

    setState(() {
      _loading = true;
      _isPreparingSharedDeck = true;
    });

    final PreSwipeProvider preSwipeProvider = context.read<PreSwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    PreparedPoolResult result;
    try {
      final PreparedPoolResult localResult = await preSwipeProvider.prepare(
        userId: userId,
        coupleProvider: coupleProvider,
        cuisines: _cuisines.toList(),
        moods: _moods.toList(),
        blocked: _blocked.toList(),
        diet: _diet.toList(),
        saveChoicesFirst: false,
      );
      if (!coupleProvider.bothConfirmed) {
        debugPrint('[Deck] prepare skipped: filters not ready');
        throw const _FiltersNotReadyException();
      }
      coupleProvider.pauseFilterStatePollingForDeckPrepare();
      var deckPrepareSucceeded = false;
      try {
        result = await preSwipeProvider.prepareBackendDeckWithFallback(localResult);
        deckPrepareSucceeded = true;
      } finally {
        coupleProvider.resumeFilterStatePollingAfterDeckPrepare(
          succeeded: deckPrepareSucceeded,
        );
      }
    } catch (e) {
      debugPrint('[PreSwipe] shared deck prepare deferred $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _isApplyingFilters = false;
        _isPreparingSharedDeck = false;
        _waitingForPartner = true;
        _hasStartedPrepareAfterBothConfirmed = false;
      });
      _startWaitingPolling();
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _isApplyingFilters = false;
      _waitingForPartner = false;
      _isPreparingSharedDeck = false;
    });

    for (final String message in result.messages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    if (result.dishes.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const _EmptyPoolScreen()),
      );
      return;
    }

    Navigator.pop(context, result);
  }

  Future<void> _skip() async {
    if (_isApplyingFilters) {
      return;
    }
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      Navigator.pop(context);
      return;
    }

    if (widget.mode == 'solo') {
      setState(() {
        _loading = true;
        _isApplyingFilters = true;
      });
      final SwipeProvider swipeProvider = context.read<SwipeProvider>();
      final bool shouldUpdateActiveSession = widget.intent == PreSwipeFilterIntent.updateActiveSoloSession || swipeProvider.activeSoloSessionId != null;
      final bool ready = shouldUpdateActiveSession
          ? await swipeProvider.rebuildActiveSoloSessionFilters(
              cuisines: const <String>[],
              moods: const <String>[],
              blocked: const <String>[],
              diet: const <String>[],
            )
          : await swipeProvider.createSoloSession(
              cuisines: const <String>[],
              moods: const <String>[],
              blocked: const <String>[],
              diet: const <String>[],
            );
      if (!mounted) {
        return;
      }
      if (ready) {
        context.read<MatchProvider>().setSoloSession(swipeProvider.activeSoloSessionId);
        final int matchedLastTime = swipeProvider.deck.length;
        await _saveBackendLastFilterPreset(matchedLastTime);
        if (!mounted) {
          return;
        }
        Navigator.pop(
          context,
          PreparedPoolResult(
            dishes: swipeProvider.deck,
            seenDishIds: <String>{},
            usedFallback: false,
            relaxed: false,
            messages: const <String>[],
          ),
        );
      } else {
        setState(() {
          _loading = false;
          _isApplyingFilters = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(swipeProvider.error ?? 'Could not update filters. You can go back to your current deck.')),
        );
      }
      return;
    }

    final CoupleProvider coupleProvider = context.read<CoupleProvider>();
    if (coupleProvider.hasCouple) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete your filters to prepare your shared deck.')),
      );
      return;
    }

    final PreSwipeProvider preSwipeProvider = context.read<PreSwipeProvider>();
    final PreparedPoolResult result = await preSwipeProvider.skip(userId);
    if (!mounted) {
      return;
    }
    Navigator.pop(context, result);
  }
}

String formatOptionLabel(String value) {
  final Set<String> uppercaseWords = <String>{'eu', 'uk', 'usa', 'us'};
  return value
      .trim()
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .map((String word) {
        final String lower = word.toLowerCase();
        if (uppercaseWords.contains(lower)) {
          return lower.toUpperCase();
        }
        return lower[0].toUpperCase() + lower.substring(1);
      })
      .join(' ');
}

class PreSwipeIntroScreen extends StatelessWidget {
  const PreSwipeIntroScreen({
    super.key,
    required this.onClose,
    required this.onCustomize,
  });

  final VoidCallback onClose;
  final VoidCallback onCustomize;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fmColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close, size: 24, color: context.fmColors.textSecondary),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerRight,
                ),
              ),
              const Spacer(),
              Image.asset(
                'assets/media/pre_swipe_intro.png',
                width: 270,
                height: 270,
              ),
              const SizedBox(height: 13),
              Text(
                'Let’s tune your food vibe.',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 38, color: context.fmColors.textPrimary, height: 1.15),
              ),
              const SizedBox(height: 18),
              Text(
                'FoodMatch has a large dish database. A few quick filters help us build a deck that feels closer to what you actually want today.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 17, height: 1.45, color: context.fmColors.textSecondary),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onCustomize,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.fmColors.buttonPrimaryBackground,
                    foregroundColor: context.fmColors.buttonPrimaryText,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Customize my feed >',
                    style: GoogleFonts.nunito(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOptionChip extends StatelessWidget {
  const _FilterOptionChip({
    required this.option,
    required this.assetPath,
    required this.assetExists,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.highlighted,
    required this.onTap,
  });

  final String option;
  final String assetPath;
  final Future<bool> assetExists;
  final String label;
  final bool selected;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? context.fmColors.primary
        : highlighted
            ? context.fmColors.success
            : context.fmColors.border;
    final Color textColor = selected
        ? context.fmColors.primary
        : enabled
            ? context.fmColors.textPrimary
            : context.fmColors.textMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(_PreSwipeFilterScreenState._chipRadius),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? context.fmColors.primarySoft : enabled ? context.fmColors.chipBackground : context.fmColors.cardElevated,
          borderRadius: BorderRadius.circular(_PreSwipeFilterScreenState._chipRadius),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected)
              Icon(
                Icons.check,
                size: 18,
                color: context.fmColors.primary,
              )
            else
              FutureBuilder<bool>(
                future: assetExists,
                builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                  final bool showSvg = snapshot.data == true;
                  if (showSvg) {
                    return SvgPicture.asset(
                      assetPath,
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(context.fmColors.textSecondary, BlendMode.srcIn),
                      placeholderBuilder: (_) => Icon(
                        Icons.restaurant_menu,
                        size: 18,
                        color: context.fmColors.textSecondary,
                      ),
                    );
                  }

                  return Icon(
                    Icons.restaurant_menu,
                    size: 18,
                    color: context.fmColors.textSecondary,
                  );
                },
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: _PreSwipeFilterScreenState._chipFontSize,
                color: textColor,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBottomPanel extends StatelessWidget {
  const _FilterBottomPanel({
    required this.cuisines,
    required this.availability,
    required this.isLoading,
    required this.canGoBack,
    required this.primaryLabel,
    required this.onBack,
    required this.onSkip,
    required this.onContinue,
  });

  final List<String> cuisines;
  final FilterAvailabilitySummary availability;
  final bool isLoading;
  final bool canGoBack;
  final String primaryLabel;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final String dishLabel = availability.availableCount == 1 ? 'dish' : 'dishes';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fmColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.fmColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '🎯 ${_summaryChoiceText()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: context.fmColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '⚡ ${availability.availableCount} $dishLabel matched',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.fmColors.primary,
                ),
              ),
            ],
          ),
          if (isLoading) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Finding your perfect dinner...', style: GoogleFonts.nunito(fontSize: 13)),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: availability.progress,
              backgroundColor: context.fmColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(context.fmColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: canGoBack ? onBack : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              // const SizedBox(width: 10),
              // TextButton(
              //   onPressed: onSkip,
              //   child: Text(
              //     'Skip',
              //     style: GoogleFonts.nunito(
              //       fontSize: 16,
              //       color: context.fmColors.primary,
              //       fontWeight: FontWeight.w700,
              //     ),
              //   ),
              // ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.fmColors.buttonPrimaryBackground,
                    foregroundColor: context.fmColors.buttonPrimaryText,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(36),
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _summaryChoiceText() {
    if (cuisines.isEmpty) {
      return 'Any cuisine';
    }
    return cuisines.map(formatOptionLabel).join(', ');
  }
}

class _EmptyPoolScreen extends StatelessWidget {
  const _EmptyPoolScreen();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'No dishes found',
                style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Try resetting filters to widen your options.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(36),
                  ),
                ),
                child: const Text('Reset filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersNotReadyException implements Exception {
  const _FiltersNotReadyException();
}
