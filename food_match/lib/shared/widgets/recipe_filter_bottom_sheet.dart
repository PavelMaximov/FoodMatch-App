import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';

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
  return showModalBottomSheet<RecipeListFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.55),
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
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
                      _FilterSectionTitle('Meal category'),
                      const SizedBox(height: 12),
                      _ChipWrap(
                        options: widget.mealOptions,
                        selected: _mealCategory == null ? const <String>{} : <String>{_mealCategory!},
                        onTap: (String value) {
                          setState(() => _mealCategory = _mealCategory == value ? null : value);
                        },
                      ),
                      const SizedBox(height: 26),
                      _FilterSectionTitle('Cooking time'),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: const Color(0xFFE7E0DD),
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withOpacity(0.14),
                          valueIndicatorColor: AppColors.primary,
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
                                    color: AppColors.textSecondary,
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 26),
                      _FilterSectionTitle('Difficulty'),
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
                        _FilterSectionTitle('Cuisine'),
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
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
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
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
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
    return Text(
      title,
      style: GoogleFonts.nunito(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
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
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: options.map((String option) {
        final bool isSelected = selected.contains(option);
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onTap(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE5E5E5),
                  width: isSelected ? 1.7 : 1.2,
                ),
              ),
              child: Text(
                option,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
