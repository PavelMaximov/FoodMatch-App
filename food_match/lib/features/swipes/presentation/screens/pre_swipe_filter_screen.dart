import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
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
  bool _loading = false;

  final Set<String> _cuisines = <String>{};
  final Set<String> _moods = <String>{};
  final Set<String> _blocked = <String>{};
  final Set<String> _diet = <String>{};
  Set<String> _favoriteCuisines = <String>{};

  List<FilterOption> _cuisineOptions = const <FilterOption>[FilterOption(label: 'Any', value: '')];

  static const List<FilterOption> _moodOptions = <FilterOption>[
    FilterOption(label: 'Comfort', value: 'comfort'),
    FilterOption(label: 'Healthy', value: 'healthy'),
    FilterOption(label: 'Exotic', value: 'exotic'),
    FilterOption(label: 'Indulgent', value: 'indulgent'),
    FilterOption(label: 'Quick', value: 'quick'),
    FilterOption(label: 'Light', value: 'light'),
  ];

  static const List<FilterOption> _exceptionOptions = <FilterOption>[
    FilterOption(label: 'Meat', value: 'meat'),
    FilterOption(label: 'Fish', value: 'fish'),
    FilterOption(label: 'Dairy', value: 'dairy'),
    FilterOption(label: 'Eggs', value: 'eggs'),
    FilterOption(label: 'Pork', value: 'pork'),
    FilterOption(label: 'Gluten', value: 'gluten'),
    FilterOption(label: 'Nuts', value: 'nuts'),
    FilterOption(label: 'Spicy', value: 'spicy'),
  ];

  static const List<FilterOption> _dietOptions = <FilterOption>[
    FilterOption(label: 'Any', value: ''),
    FilterOption(label: 'Vegetarian', value: 'vegetarian'),
    FilterOption(label: 'Vegan', value: 'vegan'),
    FilterOption(label: 'Halal', value: 'halal'),
  ];

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

      final List<FilterOption> cuisines = await context.read<PreSwipeProvider>().loadCuisineOptions();
      if (!mounted) {
        return;
      }
      setState(() => _cuisineOptions = cuisines);
    });
  }

  @override
  Widget build(BuildContext context) {
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
              Text(_subtitle, style: GoogleFonts.nunito(fontSize: 28)),
              const SizedBox(height: 24),
              Expanded(child: _buildStepContent()),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Finding your perfect dinner...'),
                ),
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
          ? 'Mood'
          : 'Exceptions';

  String get _subtitle => _step == 1
      ? 'Choose up to 3'
      : _step == 2
          ? 'Pick 1–3 vibes'
          : 'Any restrictions?';

  Widget _buildStepContent() {
    if (_step == 1) {
      return _buildChipGrid(
        options: _cuisineOptions,
        selected: _cuisines,
        onTap: _toggleCuisine,
        counts: context.read<PreSwipeProvider>().cuisineCounts(options: _cuisineOptions, selected: _cuisines),
        anySelected: _cuisines.isEmpty,
      );
    }

    if (_step == 2) {
      return _buildChipGrid(
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
        counts: context.read<PreSwipeProvider>().moodCounts(
          moods: _moodOptions,
          selectedCuisines: _cuisines,
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
            counts: context.read<PreSwipeProvider>().exclusionCounts(
              exclusions: _exceptionOptions,
              selectedCuisines: _cuisines,
              selectedBlocked: _blocked,
              selectedDiet: _diet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipGrid({
    required List<FilterOption> options,
    required Set<String> selected,
    required void Function(String) onTap,
    Map<String, PreSwipeChipState> counts = const <String, PreSwipeChipState>{},
    bool useCrossForSelected = false,
    bool anySelected = false,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((FilterOption option) {
        final bool isSelected = option.value.isEmpty ? anySelected : selected.contains(option.value);
        final bool highlighted = options == _cuisineOptions && !_cuisines.contains(option.value) && _favoriteCuisines.contains(option.label);
        final PreSwipeChipState? chipState = counts[option.value];
        final bool enabled = option.value.isEmpty ? true : (chipState?.enabled ?? true);

        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    useCrossForSelected ? Icons.close : Icons.check,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              Text('${option.label}${chipState == null ? '' : ' (${chipState.count})'}', style: GoogleFonts.nunito(fontSize: _chipFontSize)),
            ],
          ),
          selected: isSelected,
          showCheckmark: false,
          onSelected: enabled ? (_) => onTap(option.value) : null,
          selectedColor: const Color(0xFFFFEFE7),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : !enabled
                    ? const Color(0xFFBDBDBD)
                    : highlighted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFD9D9D9),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_chipRadius),
          ),
        );
      }).toList(),
    );
  }

  void _toggleCuisine(String value) {
    setState(() {
      if (value.isEmpty) {
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
      if (value.isEmpty) {
        _diet.clear();
      } else {
        if (_diet.contains(value)) {
          _diet.remove(value);
        } else {
          _diet.add(value);
        }
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

    if (!mounted) {
      return;
    }
    setState(() => _loading = false);

    for (final String message in result.messages) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
