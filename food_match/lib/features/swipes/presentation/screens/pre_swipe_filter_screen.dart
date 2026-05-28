import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/couple_filter_state.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final String? userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        final profile = await context.read<PreSwipeProvider>().loadProfile(userId);
        if (mounted) {
          setState(() => _favoriteCuisines = profile.favoriteCuisines.toSet());
        }
      }

      context.read<CoupleProvider>().startFilterStatePolling();
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
  Widget build(BuildContext context) {
    if (_showIntro) {
      return PreSwipeIntroScreen(
        onClose: () => Navigator.of(context).pop(),
        onCustomize: () => setState(() => _showIntro = false),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                style: GoogleFonts.pacifico(fontSize: 42, color: const Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 10),
              Text(_subtitle, style: GoogleFonts.nunito(fontSize: 18, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Expanded(child: _buildStepContent()),
              const SizedBox(height: 16),
              Consumer<CoupleProvider>(
                builder: (BuildContext context, CoupleProvider coupleProvider, _) {
                  return _FilterSummaryPanel(
                    cuisines: _cuisines.toList(),
                    moods: _moods.toList(),
                    diet: _diet.toList(),
                    exclusions: _blocked.toList(),
                    coupleProvider: coupleProvider,
                    availability: context.read<PreSwipeProvider>().buildAvailabilitySummary(
                          allDishes: _allDishes,
                          cuisines: _cuisines.toList(),
                          moods: _moods.toList(),
                          blocked: _blocked.toList(),
                          diet: _diet.toList(),
                          partnerChoices: coupleProvider.partnerChoices,
                        ),
                  );
                },
              ),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text('Finding your perfect dinner...', style: GoogleFonts.nunito()),
                ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _step == 1 ? null : () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_buttonRadius),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _loading ? null : _skip,
                    child: Text('Skip', style: GoogleFonts.nunito(fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_buttonRadius),
                        ),
                      ),
                      child: Text(_step == 3 ? 'Confirm' : 'Continue'),
                    ),
                  ),
                ],
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
          ? 'What are you in the mood for?'
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
            useCrossForSelected: true,
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
            useCrossForSelected: true,
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
    bool useCrossForSelected = false,
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
          label: _chipLabel(option, chipState),
          selected: isSelected,
          enabled: isEnabled,
          highlighted: highlighted,
          useCrossForSelected: useCrossForSelected,
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

  String _chipLabel(String option, FilterChipState? chipState) {
    final String label = _displayLabel(option);
    if (chipState == null || option == 'Any') {
      return label;
    }
    return '$label (${chipState.count})';
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
        return _formatOptionLabel(value);
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

    setState(() => _loading = true);
    final DateTime started = DateTime.now();
    final PreparedPoolResult result = await context.read<PreSwipeProvider>().prepare(
          userId: userId,
          coupleProvider: context.read<CoupleProvider>(),
          cuisines: _cuisines.toList(),
          moods: _moods.toList(),
          blocked: _blocked.toList(),
          diet: _diet.toList(),
        );

    final int elapsed = DateTime.now().difference(started).inMilliseconds;
    if (elapsed > 300) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    await context.read<CoupleProvider>().confirmMyChoices();

    if (!mounted) {
      return;
    }
    setState(() => _loading = false);

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

    final PreparedPoolResult result = await context.read<PreSwipeProvider>().skip(userId);
    if (!mounted) {
      return;
    }
    Navigator.pop(context, result);
  }
}

String _formatOptionLabel(String value) {
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
              SvgPicture.asset(
                'assets/icons/pre_swipe_intro.svg',
                width: 170,
                height: 170,
              ),
              const SizedBox(height: 36),
              Text(
                'Before you start swiping...',
                textAlign: TextAlign.center,
                style: GoogleFonts.pacifico(fontSize: 38, color: AppColors.textPrimary, height: 1.15),
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
    required this.useCrossForSelected,
    required this.onTap,
    this.icon = Icons.restaurant_menu,
    this.iconAsset,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool highlighted;
  final bool useCrossForSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = selected
        ? AppColors.primary
        : highlighted
            ? AppColors.success
            : const Color(0xFFD9D9D9);
    final Color textColor = enabled ? AppColors.textPrimary : AppColors.textHint;

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
              Icon(
                useCrossForSelected ? Icons.close : Icons.check,
                size: 18,
                color: AppColors.primary,
              )
            else if (iconAsset != null)
              SvgPicture.asset(iconAsset!, width: 18, height: 18)
            else
              Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.nunito(fontSize: _PreSwipeFilterScreenState._chipFontSize, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSummaryPanel extends StatelessWidget {
  const _FilterSummaryPanel({
    required this.cuisines,
    required this.moods,
    required this.diet,
    required this.exclusions,
    required this.coupleProvider,
    required this.availability,
  });

  final List<String> cuisines;
  final List<String> moods;
  final List<String> diet;
  final List<String> exclusions;
  final CoupleProvider coupleProvider;
  final FilterAvailabilitySummary availability;

  @override
  Widget build(BuildContext context) {
    final bool hasPartnerChoices = availability.usesPartnerChoices;
    final String availabilityTitle = hasPartnerChoices ? '⚡ Match result:' : '⚡ Available dishes:';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0D0D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('🎯 Your choice:', style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ..._choiceLines(),
          if (coupleProvider.hasCouple) ...<Widget>[
            const SizedBox(height: 8),
            Text(_partnerStatusText(), style: GoogleFonts.nunito(fontSize: 14, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 18),
          Text(availabilityTitle, style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_availabilityCopy(), style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textPrimary)),
          if (coupleProvider.hasCouple && !hasPartnerChoices)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                coupleProvider.partnerChoices == null
                    ? 'Waiting for partner choices. Showing your current result.'
                    : 'Partner choices will update this result.',
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: availability.progress,
              backgroundColor: const Color(0xFFE8E0DC),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${availability.availableCount} of ${availability.totalCount} dishes available',
            style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(availability.helperText, style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  List<Widget> _choiceLines() {
    final List<Widget> lines = <Widget>[];
    void addLine(String label, List<String> values) {
      if (values.isEmpty) {
        return;
      }
      lines.add(Text(
        '$label: ${values.map(_formatOptionLabel).join(', ')}',
        style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textPrimary),
      ));
    }

    addLine('Cuisine', cuisines);
    addLine('Mood priority', moods);
    addLine('Diet', diet);
    addLine('Exclusions', exclusions);

    if (lines.isEmpty) {
      return <Widget>[Text('No choices yet', style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary))];
    }
    return lines;
  }

  String _availabilityCopy() {
    final String suffix = availability.usesPartnerChoices ? 'match both your choices' : 'match your current setup';
    return '${availability.availableCount} dishes $suffix';
  }

  String _partnerStatusText() {
    if (!coupleProvider.hasCouple) {
      return '';
    }
    if ((coupleProvider.currentCouple?.members.length ?? 0) < 2) {
      return 'Partner: Waiting for partner...';
    }
    if (coupleProvider.bothConfirmed || coupleProvider.isPartnerReady) {
      return 'Partner: Ready';
    }
    final CoupleFilterChoices? partnerChoices = coupleProvider.partnerChoices;
    final bool hasChoices = partnerChoices != null &&
        (partnerChoices.cuisines.isNotEmpty ||
            partnerChoices.moods.isNotEmpty ||
            partnerChoices.diet.isNotEmpty ||
            partnerChoices.exclusions.isNotEmpty);
    return hasChoices ? 'Partner: Choices received' : 'Partner: Waiting for choices...';
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
