import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme_extensions.dart';
import '../../core/widgets/food_match_ripple.dart';

class RecipeListFilters {
  const RecipeListFilters({
    this.mealCategory,
    this.maxCookTime,
    this.difficulty,
    this.cuisines = const <String>{},
  });

  final String? mealCategory;
  final int? maxCookTime;
  final String? difficulty;
  final Set<String> cuisines;

  bool get hasActiveFilters =>
      mealCategory != null ||
      maxCookTime != null ||
      difficulty != null ||
      cuisines.isNotEmpty;

  RecipeListFilters copyWith({
    String? mealCategory,
    int? maxCookTime,
    String? difficulty,
    Set<String>? cuisines,
    bool clearMealCategory = false,
    bool clearMaxCookTime = false,
    bool clearDifficulty = false,
  }) {
    return RecipeListFilters(
      mealCategory: clearMealCategory ? null : mealCategory ?? this.mealCategory,
      maxCookTime: clearMaxCookTime ? null : maxCookTime ?? this.maxCookTime,
      difficulty: clearDifficulty ? null : difficulty ?? this.difficulty,
      cuisines: cuisines ?? this.cuisines,
    );
  }
}

Future<RecipeListFilters?> showRecipeFilterBottomSheet({
  required BuildContext context,
  required RecipeListFilters filters,
  required List<String> mealOptions,
  required List<String> cuisineOptions,
}) {
  final FoodMatchThemeColors colors = context.fmColors;
  return showModalBottomSheet<RecipeListFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.modalBarrier,
    builder: (BuildContext context) => RecipeFilterBottomSheet(
      initialFilters: filters,
      mealOptions: mealOptions,
      cuisineOptions: cuisineOptions,
    ),
  );
}

class RecipeFilterBottomSheet extends StatefulWidget {
  const RecipeFilterBottomSheet({
    super.key,
    required this.initialFilters,
    required this.mealOptions,
    required this.cuisineOptions,
  });

  final RecipeListFilters initialFilters;
  final List<String> mealOptions;
  final List<String> cuisineOptions;

  @override
  State<RecipeFilterBottomSheet> createState() => _RecipeFilterBottomSheetState();
}

class _RecipeFilterBottomSheetState extends State<RecipeFilterBottomSheet> {
  static const List<int> _cookTimes = <int>[15, 30, 45, 60];
  static const List<String> _difficulties = <String>['Easy', 'Medium', 'Hard'];

  late String? _mealCategory = widget.initialFilters.mealCategory;
  late int? _maxCookTime = widget.initialFilters.maxCookTime;
  late String? _difficulty = widget.initialFilters.difficulty;
  late Set<String> _cuisines = <String>{...widget.initialFilters.cuisines};

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.sizeOf(context).height * 0.78;
    final FoodMatchThemeColors colors = context.fmColors;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.modalBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 14, 0),
                child: Row(
                  children: <Widget>[
                    Text(
                      'Filters',
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _FilterSectionTitle('Meal category'),
                      const SizedBox(height: 12),
                      _ChipWrap(
                        options: widget.mealOptions,
                        selected: _mealCategory == null ? const <String>{} : <String>{_mealCategory!},
                        onTap: (String value) {
                          setState(() => _mealCategory = _mealCategory == value ? null : value);
                        },
                      ),
                      const SizedBox(height: 26),
                      const _FilterSectionTitle('Cooking time'),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: colors.primary,
                          inactiveTrackColor: colors.divider,
                          thumbColor: colors.primary,
                          overlayColor: colors.primary.withValues(alpha: 0.14),
                          valueIndicatorColor: colors.primary,
                        ),
                        child: Slider(
                          min: 15,
                          max: 60,
                          divisions: 3,
                          value: (_maxCookTime ?? 60).toDouble(),
                          label: '${_maxCookTime ?? 60} min',
                          onChanged: (double value) => setState(() => _maxCookTime = value.round()),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: _cookTimes
                            .map((int minutes) => Text(
                                  '$minutes min',
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textSecondary,
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 26),
                      const _FilterSectionTitle('Difficulty'),
                      const SizedBox(height: 12),
                      _ChipWrap(
                        options: _difficulties,
                        selected: _difficulty == null ? const <String>{} : <String>{_difficulty!},
                        onTap: (String value) {
                          setState(() => _difficulty = _difficulty == value ? null : value);
                        },
                      ),
                      if (widget.cuisineOptions.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 26),
                        const _FilterSectionTitle('Cuisine'),
                        const SizedBox(height: 12),
                        _ChipWrap(
                          options: widget.cuisineOptions,
                          selected: _cuisines,
                          onTap: (String value) {
                            setState(() {
                              if (_cuisines.contains(value)) {
                                _cuisines.remove(value);
                              } else {
                                _cuisines.add(value);
                              }
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _mealCategory = null;
                          _maxCookTime = null;
                          _difficulty = null;
                          _cuisines = <String>{};
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.buttonSecondaryText,
                          side: BorderSide(color: colors.borderStrong, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text(
                          'Clear all',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(
                          RecipeListFilters(
                            mealCategory: _mealCategory,
                            maxCookTime: _maxCookTime,
                            difficulty: _difficulty,
                            cuisines: <String>{..._cuisines},
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.buttonPrimaryBackground,
                          foregroundColor: colors.buttonPrimaryText,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text(
                          'Apply',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Text(
      title,
      style: GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: colors.textPrimary,
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: options.map((String option) {
        final bool isSelected = selected.contains(option);
        return FoodMatchRipple(
          onTap: () => onTap(option),
          borderRadius: BorderRadius.circular(999),
          rippleColor: colors.neutralRipple,
          child: Material(
            color: colors.chipBackground,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? colors.chipSelectedBorder : colors.chipBorder,
                  width: isSelected ? 1.7 : 1.2,
                ),
              ),
              child: Text(
                option,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? colors.primary : colors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
