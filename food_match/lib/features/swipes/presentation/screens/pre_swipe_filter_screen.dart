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
  bool _waitingForPartner = false;

  final Set<String> _cuisines = <String>{};
  final Set<String> _moods = <String>{};
  final Set<String> _blocked = <String>{};
  final Set<String> _diet = <String>{};
  Set<String> _favoriteCuisines = <String>{};

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
      if (userId != null) {
        await context.read<CoupleProvider>().startFilterStatePolling();
        final profile = await context.read<PreSwipeProvider>().loadProfile(userId);
        if (mounted) {
          setState(() => _favoriteCuisines = profile.favoriteCuisines.toSet());
        }
        await _pushDraftUpdate();
      }

      final List<String> cuisines = await context.read<PreSwipeProvider>().loadCuisineOptions();
      if (!mounted) {
        return;
      }
      setState(() => _cuisineOptions = cuisines);
    });
  }

  @override
  void dispose() {
    context.read<CoupleProvider>().stopFilterStatePolling();
    super.dispose();
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
              _buildCompatibilityCard(),
              const SizedBox(height: 16),
              Expanded(child: _buildStepContent()),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Finding your perfect dinner...'),
                ),
              if (_waitingForPartner)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Waiting for partner confirmation...'),
                    ],
                  ),
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
      );
    }

    if (_step == 2) {
      return _buildChipGrid(
        options: _moodOptions,
        selected: _moods,
        onTap: (String value) {
          setState(() {
            _waitingForPartner = false;
            if (_moods.contains(value)) {
              _moods.remove(value);
            } else if (_moods.length < 3) {
              _moods.add(value);
            }
          });
          unawaited(_pushDraftUpdate());
        },
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
                _waitingForPartner = false;
                if (_blocked.contains(value)) {
                  _blocked.remove(value);
                } else {
                  _blocked.add(value);
                }
              });
              unawaited(_pushDraftUpdate());
            },
            useCrossForSelected: true,
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
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((String option) {
        final bool isSelected = selected.contains(option);
        final bool highlighted = options == _cuisineOptions && !_cuisines.contains(option) && _favoriteCuisines.contains(option);

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
              Text(option, style: GoogleFonts.nunito(fontSize: _chipFontSize)),
            ],
          ),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onTap(option),
          selectedColor: const Color(0xFFFFEFE7),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
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
      _waitingForPartner = false;
      if (value == 'Any') {
        if (_cuisines.contains('Any')) {
          _cuisines.remove('Any');
        } else {
          _cuisines
            ..clear()
            ..add('Any');
        }
        return;
      }

      _cuisines.remove('Any');
      if (_cuisines.contains(value)) {
        _cuisines.remove(value);
      } else if (_cuisines.length < 3) {
        _cuisines.add(value);
      }
    });
    unawaited(_pushDraftUpdate());
  }

  void _toggleDiet(String value) {
    setState(() {
      _waitingForPartner = false;
      if (value == 'Any') {
        if (_diet.contains('Any')) {
          _diet.remove('Any');
        } else {
          _diet
            ..clear()
            ..add('Any');
        }
      } else {
        _diet.remove('Any');
        if (_diet.contains(value)) {
          _diet.remove(value);
        } else {
          _diet.add(value);
        }
      }
    });
    unawaited(_pushDraftUpdate());
  }

  Future<void> _next() async {
    if (_step < 3) {
      if (_step == 2 && _moods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose at least one mood')),
        );
        return;
      }
      await _pushDraftUpdate();
      setState(() => _step++);
      return;
    }

    final String? userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      Navigator.pop(context);
      return;
    }

    await _pushDraftUpdate(confirmed: true);
    await context.read<CoupleProvider>().refreshFilterState();
    if (!mounted) {
      return;
    }
    if (!context.read<CoupleProvider>().isPartnerConfirmed(userId)) {
      setState(() => _waitingForPartner = true);
      return;
    }

    setState(() {
      _loading = true;
      _waitingForPartner = false;
    });
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

    await context.read<CoupleProvider>().clearRemoteFilterState();
    final PreparedPoolResult result = await context.read<PreSwipeProvider>().skip(userId);
    if (!mounted) {
      return;
    }
    Navigator.pop(context, result);
  }

  Future<void> _pushDraftUpdate({bool confirmed = false}) async {
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      return;
    }
    await context.read<CoupleProvider>().pushSessionDraft(
          userId: userId,
          step: _step,
          cuisines: _cuisines.toList(),
          moods: _moods.toList(),
          blocked: _blocked.toList(),
          diet: _diet.toList(),
          confirmed: confirmed,
        );
  }

  Widget _buildCompatibilityCard() {
    final String? userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) {
      return const SizedBox.shrink();
    }
    return Consumer<CoupleProvider>(
      builder: (BuildContext context, CoupleProvider couple, _) {
        final PartnerSessionChoices partner = couple.partnerChoicesFor(userId);
        final int stepCompatibility = couple.stepCompatibility(step: _step, userId: userId);
        final int overall = couple.overallCompatibility(userId: userId);
        final List<String> partnerStepChoices = _step == 1
            ? partner.cuisines
            : _step == 2
                ? partner.moods
                : <String>[...partner.diet, ...partner.blocked];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E4E4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Compatibility: $stepCompatibility% (overall $overall%)'),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: stepCompatibility / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: const Color(0xFFF1F1F1),
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                partnerStepChoices.isEmpty
                    ? 'Partner has not selected this step yet.'
                    : 'Partner picked: ${partnerStepChoices.join(', ')}',
                style: GoogleFonts.nunito(fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
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
