import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../couple/logic/couple_provider.dart';
import '../../logic/pre_swipe_provider.dart';

class PreSwipeFilterScreen extends StatefulWidget {
  const PreSwipeFilterScreen({super.key});

  @override
  State<PreSwipeFilterScreen> createState() => _PreSwipeFilterScreenState();
}

class _PreSwipeFilterScreenState extends State<PreSwipeFilterScreen> {
  int _step = 1;
  bool _loading = false;

  final Set<String> _cuisines = <String>{};
  final Set<String> _moods = <String>{};
  final Set<String> _blocked = <String>{};
  final Set<String> _diet = <String>{};
  Set<String> _favoriteCuisines = <String>{};

  static const List<String> _cuisineOptions = <String>[
    'Any',
    'American',
    'Italian',
    'Asian',
    'Japanese',
    'Mexican',
    'French',
    'Indian',
    'Mediterranean',
  ];

  static const List<String> _moodOptions = <String>[
    'Comfort',
    'Healthy',
    'Exotic',
    'Indulgent',
    'Quick',
    'Light',
  ];

  static const List<String> _exceptionOptions = <String>[
    'Meat',
    'Fish',
    'Dairy',
    'Eggs',
    'Pork',
    'Gluten',
    'Nuts',
    'Spicy',
  ];

  static const List<String> _dietOptions = <String>['Any', 'Vegetarian', 'Vegan', 'Halal'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final String? userId = context.read<AuthProvider>().currentUser?.id;
      if (userId == null) {
        return;
      }
      final profile = await context.read<PreSwipeProvider>().loadProfile(userId);
      if (!mounted) {
        return;
      }
      setState(() => _favoriteCuisines = profile.favoriteCuisines.toSet());
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
                  Text('Step $_step / 3', style: GoogleFonts.nunito(fontSize: 14)),
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
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _loading ? null : _skip,
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildChipGrid(options: _dietOptions, selected: _diet, onTap: _toggleDiet),
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
          ),
        ],
      ),
    );
  }

  Widget _buildChipGrid({
    required List<String> options,
    required Set<String> selected,
    required void Function(String) onTap,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((String option) {
        final bool isSelected = selected.contains(option);
        final bool isDisabled = options == _cuisineOptions && _cuisines.contains('Any') && option != 'Any';
        final bool highlighted =
            options == _cuisineOptions && !_cuisines.contains(option) && _favoriteCuisines.contains(option);

        return ChoiceChip(
          label: Text(option),
          selected: isSelected,
          onSelected: isDisabled ? null : (_) => onTap(option),
          selectedColor: const Color(0xFFFFEFE7),
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : highlighted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFD9D9D9),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
          ),
        );
      }).toList(),
    );
  }

  void _toggleCuisine(String value) {
    setState(() {
      if (value == 'Any') {
        _cuisines
          ..clear()
          ..add('Any');
        return;
      }
      _cuisines.remove('Any');
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
        _diet
          ..clear()
          ..add('Any');
      } else {
        _diet.remove('Any');
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
      if (_step == 2 && _moods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose at least one mood')),
        );
        return;
      }
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
          cuisines: _cuisines.where((String e) => e != 'Any').toList(),
          moods: _moods.toList(),
          blocked: _blocked.toList(),
          diet: _diet.where((String e) => e != 'Any').toList(),
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

    if (result.relaxed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Widened filter to find more options')),
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
                child: const Text('Reset filters'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
