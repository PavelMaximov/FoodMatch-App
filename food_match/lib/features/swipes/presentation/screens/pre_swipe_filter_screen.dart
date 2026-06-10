import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/dish.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../logic/filter_scoring_service.dart';
import '../../logic/pre_swipe_provider.dart';

class PreSwipeFilterScreen extends StatefulWidget {
  const PreSwipeFilterScreen({super.key});

  @override
  State<PreSwipeFilterScreen> createState() => _PreSwipeFilterScreenState();
}

class _PreSwipeFilterScreenState extends State<PreSwipeFilterScreen> {
  static const double _chipRadius = 15;
  static const double _buttonRadius = 15;
  static const double _chipFontSize = 17;

  int _step = 1;
  bool _showIntro = true;
  bool _loading = false;
  bool _waitingForPartner = false;
  bool _isPreparingSharedDeck = false;
  bool _hasStartedPrepareAfterBothConfirmed = false;
  String? _pendingUserId;
  late final CoupleProvider _coupleProvider;

  final Set<String> _cuisines = <String>{};
  final Set<String> _moods = <String>{};
  final Set<String> _blocked = <String>{};
  final Set<String> _diet = <String>{};
  Set<String> _favoriteCuisines = <String>{};
  List<Dish> _allDishes = <Dish>[];

  List<String> _cuisineOptions = <String>['Any'];

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
      if (userId != null) {
        final profile = await context.read<PreSwipeProvider>().loadProfile(userId);
        if (mounted) {
          setState(() => _favoriteCuisines = profile.favoriteCuisines.toSet());
        }
      }
      if (!mounted) {
        return;
      }

      _coupleProvider.startFilterStatePolling();
      await _coupleProvider.refreshFilterState();
      if (!mounted) {
        return;
      }
      if (_coupleProvider.isMyChoicesConfirmed && !_coupleProvider.bothConfirmed) {
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
      });
    });
  }

  @override
  void dispose() {
    _coupleProvider.stopFilterStatePolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return PreSwipeIntroScreen(
        onClose: () => Navigator.of(context).pop(),
        onCustomize: () => setState(() => _showIntro = false),
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
      backgroundColor: AppColors.background,
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
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                _title,
                style: AppTextStyles.pageTitle.copyWith(color: const Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 10),
              Text(_subtitle, style: GoogleFonts.nunito(fontSize: 18, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Expanded(child: _buildStepContent()),
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
                          partnerChoices: coupleProvider.partnerChoices,
                        ),
                    isLoading: _loading,
                    canGoBack: _step > 1,
                    primaryLabel: _step == 3 ? 'Confirm' : 'Continue',
                    onBack: _step == 1 ? null : () => setState(() => _step--),
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
        child: _buildChipGrid(
          options: _cuisineOptions,
          selected: _cuisines,
          onTap: _toggleCuisine,
          chipStates: context.read<PreSwipeProvider>().buildCuisineChipStates(_cuisineOptions, _allDishes),
          anyWhenEmpty: true,
        ),
      );
    }

    if (_step == 2) {
      return SingleChildScrollView(
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
      );
    }

    return SingleChildScrollView(
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
      spacing: 10,
      runSpacing: 10,
      children: options.map((String option) {
        final FilterChipState? chipState = _chipStateFor(option, chipStates);
        final bool isAny = option == 'Any';
        final bool isSelected = anyWhenEmpty && isAny ? selected.isEmpty : selected.contains(option);
        final bool isEnabled = chipState?.enabled ?? true;
        final bool highlighted = options == _cuisineOptions && !_cuisines.contains(option) && _favoriteCuisines.contains(option);

        return _FilterOptionChip(
          label: _chipLabel(option),
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

  Future<void> _next() async {
    if (_step < 3) {
      setState(() => _step++);
      return;
    }

    final String? userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      Navigator.pop(context);
      return;
    }
    final PreSwipeProvider preSwipeProvider = context.read<PreSwipeProvider>();
    final CoupleProvider coupleProvider = context.read<CoupleProvider>();

    setState(() => _loading = true);
    await preSwipeProvider.saveChoices(
      userId: userId,
      coupleProvider: coupleProvider,
      cuisines: _cuisines.toList(),
      moods: _moods.toList(),
      blocked: _blocked.toList(),
      diet: _diet.toList(),
    );

    if (!mounted) {
      return;
    }
    await coupleProvider.confirmMyChoices();
    await coupleProvider.refreshFilterState();

    if (!mounted) {
      return;
    }

    if (!coupleProvider.bothConfirmed) {
      debugPrint('[PreSwipe] waiting for partner filters');
      setState(() {
        _loading = false;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(48),
                  ),
                  child: const Icon(Icons.hourglass_empty, size: 44, color: AppColors.primary),
                ),
                const SizedBox(height: 28),
                Text(
                  _isPreparingSharedDeck ? 'Preparing your shared deck...' : 'Waiting for your partner...',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 38, color: const Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 14),
                Text(
                  _isPreparingSharedDeck
                      ? 'Both filter sets are ready. We’re preparing your shared deck now.'
                      : 'Your choices are saved. We’ll start swiping when your partner finishes their filters.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(fontSize: 17, color: AppColors.textSecondary, height: 1.35),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 28),
                TextButton(
                  onPressed: _isPreparingSharedDeck ? null : () => Navigator.of(context).pop(),
                  child: const Text('Back to session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startWaitingPolling() {
    _coupleProvider.startFilterStatePolling();
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
      result = await preSwipeProvider.prepareBackendDeckWithFallback(localResult);
      await coupleProvider.refreshFilterState();
    } catch (e) {
      debugPrint('[PreSwipe] shared deck prepare deferred $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
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
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      Navigator.pop(context);
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 30, color: AppColors.textSecondary),
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
                'Before you start swiping...',
                textAlign: TextAlign.center,
                style: GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 38, color: AppColors.textPrimary, height: 1.15),
              ),
              const SizedBox(height: 18),
              Text(
                'We have over 200 dishes in our database. Without filters, that\'s a lot of swiping. Answer a few quick questions about your food preferences and we\'ll show you dishes that better match your taste and your partner\'s choice.',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(fontSize: 17, height: 1.45, color: AppColors.textSecondary),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onCustomize,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
    required this.label,
    required this.selected,
    required this.enabled,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? AppColors.primary
        : highlighted
            ? AppColors.success
            : const Color(0xFFD9D9D9);
    final Color textColor = selected
        ? AppColors.primary
        : enabled
            ? AppColors.textPrimary
            : AppColors.textHint;

    return InkWell(
      borderRadius: BorderRadius.circular(_PreSwipeFilterScreenState._chipRadius),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFEFE7) : enabled ? Colors.white : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(_PreSwipeFilterScreenState._chipRadius),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected)
              const Icon(
                Icons.check,
                size: 18,
                color: AppColors.primary,
              )
            else
              // TODO: replace placeholder option icon with per-category assets.
              const Icon(Icons.restaurant_menu, size: 18, color: AppColors.textSecondary),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D0D0)),
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
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '⚡ ${availability.availableCount} $dishLabel',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
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
              value: availability.totalCount <= 0 ? 0 : availability.progress,
              backgroundColor: const Color(0xFFE8E0DC),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                      borderRadius: BorderRadius.circular(_PreSwipeFilterScreenState._buttonRadius),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_PreSwipeFilterScreenState._buttonRadius),
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
                    borderRadius: BorderRadius.circular(_PreSwipeFilterScreenState._buttonRadius),
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
