import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/repositories/dish_repository.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/media/safe_dish_image.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../shared/widgets/dish_grid.dart';
import '../../../favorites/logic/favorites_provider.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

const double kRecipeChipRadius = 15;
const double kRecipeChipBorderWidth = 1.6;
const Color kRecipeChipBorderColor = Color(0xFFE2DBD8);
const Color kRecipeChipBackgroundColor = Colors.white;

enum MealTabType { breakfast, lunch, dinner, snack }

class RecipeResultsQuery {
  const RecipeResultsQuery({
    this.cuisine,
    this.type,
    this.mealType,
    this.mood = const <String>[],
    this.diet = const <String>[],
    this.effort,
    this.popular,
    this.maxCookTime,
    this.maxTotalTime,
    this.timeTier,
    this.maxIngredients,
    this.sort = 'default',
  });

  final String? cuisine;
  final String? type;
  final String? mealType;
  final List<String> mood;
  final List<String> diet;
  final String? effort;
  final bool? popular;
  final int? maxCookTime;
  final int? maxTotalTime;
  final String? timeTier;
  final int? maxIngredients;
  final String sort;

  RecipeResultsQuery copyWith({
    String? cuisine,
    String? type,
    String? mealType,
    List<String>? mood,
    List<String>? diet,
    String? effort,
    bool? popular,
    int? maxCookTime,
    int? maxTotalTime,
    String? timeTier,
    int? maxIngredients,
    String? sort,
  }) {
    return RecipeResultsQuery(
      cuisine: cuisine ?? this.cuisine,
      type: type ?? this.type,
      mealType: mealType ?? this.mealType,
      mood: mood ?? this.mood,
      diet: diet ?? this.diet,
      effort: effort ?? this.effort,
      popular: popular ?? this.popular,
      maxCookTime: maxCookTime ?? this.maxCookTime,
      maxTotalTime: maxTotalTime ?? this.maxTotalTime,
      timeTier: timeTier ?? this.timeTier,
      maxIngredients: maxIngredients ?? this.maxIngredients,
      sort: sort ?? this.sort,
    );
  }
}

bool _matchesToken(String rawValue, String target) {
  final String v = rawValue.trim().toLowerCase();
  if (v.isEmpty) {
    return false;
  }
  if (v == target) {
    return true;
  }
  // split on common separators and whitespace
  final List<String> tokens = v
      .split(RegExp(r'[\s\/,&|]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (tokens.contains(target)) {
    return true;
  }
  // word-boundary match as a fallback
  return RegExp(r'\b' + RegExp.escape(target) + r'\b').hasMatch(v);
}

bool matchesMealTab(Dish dish, MealTabType tab) {
  final Set<String> tags = dish.tags.map((e) => e.trim()).where((s) => s.isNotEmpty).toSet();
  final Set<String> mood = dish.mood.map((e) => e.trim()).where((s) => s.isNotEmpty).toSet();
  final String type = dish.type.trim();
  final String target = tab.name.toLowerCase();

  for (final t in tags) {
    if (_matchesToken(t, target)) {
      return true;
    }
  }
  for (final m in mood) {
    if (_matchesToken(m, target)) {
      return true;
    }
  }
  if (_matchesToken(type, target)) {
    return true;
  }
  return false;
}

class RecipeCategoryConfig {
  const RecipeCategoryConfig({
    required this.id,
    required this.title,
    required this.assetName,
    required this.filter,
    this.query = const RecipeResultsQuery(sort: 'default'),
    this.postFilter,
  });

  final String id;
  final String title;
  final String assetName;
  final bool Function(Dish dish) filter;
  final RecipeResultsQuery query;
  final bool Function(Dish dish)? postFilter;
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Dish> _allDishes = <Dish>[];
  bool _isLoading = false;
  String? _error;

  final Set<String> _selectedCuisines = <String>{};
  final Set<String> _selectedMoods = <String>{};
  final Set<String> _selectedDiet = <String>{};
  final Set<String> _selectedTypes = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final DishRepository repository = context.read<DishRepository>();
    final FavoritesProvider favoritesProvider = context.read<FavoritesProvider>();
    try {
      final List<Dish> dishes = await repository.getCatalogDishes(force: force);
      await favoritesProvider.loadFavorites(force: force);
      if (!mounted) {
        return;
      }
      setState(() => _allDishes = dishes);
      debugPrint('[Recipes] loaded dishes=${dishes.length}');
      final List<List<String>> firstFiveTags = dishes
          .take(5)
          .map((Dish dish) => dish.tags)
          .toList();
      debugPrint('[Recipes] first5.tags=$firstFiveTags');
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = ErrorMessages.fromException(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSaved(Dish dish) async {
    await context.read<FavoritesProvider>().toggleFavorite(dish);
    if (!mounted) {
      return;
    }
    final String? error = context.read<FavoritesProvider>().error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _openFavorites() async {
    await context.push('/favorites');
    if (mounted) {
      await _loadData();
    }
  }

  void _openSearch() {
    showSearch<Dish?>(
      context: context,
      delegate: _RecipeSearchDelegate(
        dishes: _allDishes,
        savedDishIds: context.read<FavoritesProvider>().savedDishIds,
        onFavoriteTap: _toggleSaved,
      ),
    ).then((Dish? selected) {
      if (selected == null || !mounted) {
        return;
      }
      context.push('/recipe-detail/${selected.id}', extra: selected);
    });
  }

  Future<void> _openFilters() async {
    final bool hasFilterOptions = _availableCuisines.isNotEmpty ||
        _availableMoods.isNotEmpty ||
        _availableDiet.isNotEmpty ||
        _availableTypes.isNotEmpty;
    if (!hasFilterOptions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filters are coming soon')),
      );
      return;
    }

    final _FilterSelection? next = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _FilterSheet(
          cuisines: _availableCuisines,
          moods: _availableMoods,
          diet: _availableDiet,
          types: _availableTypes,
          selectedCuisines: _selectedCuisines,
          selectedMoods: _selectedMoods,
          selectedDiet: _selectedDiet,
          selectedTypes: _selectedTypes,
        ),
      ),
    );

    if (next == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCuisines
        ..clear()
        ..addAll(next.cuisines);
      _selectedMoods
        ..clear()
        ..addAll(next.moods);
      _selectedDiet
        ..clear()
        ..addAll(next.diet);
      _selectedTypes
        ..clear()
        ..addAll(next.types);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Recipes',
                          style: AppTextStyles.pageTitle,
                        ),
                      ),
                      _FavoritesPillButton(
                        count: context.select<FavoritesProvider, int>((FavoritesProvider p) => p.savedDishes.length),
                        onTap: _openFavorites,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _RecipeSearchBar(onSearchTap: _openSearch),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadData(force: true),
                child: _buildBody(),
              ),
            ),
          ],
          ),
        ),
      );
    
  }

  Widget _buildBody() {
    if (_isLoading && _allDishes.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: SizedBox(height: 210, child: ShimmerCard()),
        ),
      );
    }

    if (_error != null && _allDishes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: 420,
            child: ErrorState(message: _error!, onRetry: _loadData),
          ),
        ],
      );
    }

    final List<Dish> activePool = _buildActivePool(tab: null);
    final List<RecipeCategoryConfig> categories = _visibleCategories(
      activePool,
    );
    // final int germanCount = activePool
    //     .where((Dish d) => d.cuisine.trim().toLowerCase() == 'german')
    //     .length;
    // debugPrint('[Recipes] German Favorites count=$germanCount');
    final List<Dish> preview = _previewRecipes(activePool);
    final bool hasPreview = preview.isNotEmpty;

    final Set<String> savedDishIds = context.select<FavoritesProvider, Set<String>>((FavoritesProvider p) => p.savedDishIds);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        MealTabsBar(selected: null, onSelected: _openMealTabPage),
        const SizedBox(height: 18),
        if (categories.isNotEmpty) ...<Widget>[
          Text(
            'Popular Categories',
            style: GoogleFonts.nunito(
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          PopularCategoriesGrid(categories: categories, onTap: _openCategory),
          const SizedBox(height: 18),
        ],
        if (activePool.isEmpty) ...<Widget>[
          const SizedBox(height: 24),
          const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No recipes found',
            subtitle: 'No dishes match the selected meal tab and filters.',
          ),
          const SizedBox(height: 20),
        ],
        if (hasPreview) ...<Widget>[
          GestureDetector(
            onTap: _openAllRecipes,
            child: Row(
              children: <Widget>[
                Text(
                  'All Recipes',
                  style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text(
                  ' >',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          DishGrid(
            dishes: preview,
            savedDishIds: savedDishIds,
            onFavoriteTap: _toggleSaved,
            onDishTap: (Dish dish) => context.push('/recipe-detail/${dish.id}', extra: dish),
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
          ),
        ],
      ],
    );
  }

  List<Dish> _buildActivePool({required MealTabType? tab}) {
    final List<Dish> basePool = _filteredDishes;
    if (tab == null) {
      return basePool;
    }
    final List<Dish> filtered = basePool
        .where((Dish dish) => matchesMealTab(dish, tab))
        .toList();
    debugPrint(
      '[Recipes] mealTab=${tab.name} all=${basePool.length} filtered=${filtered.length}',
    );
    return filtered;
  }

  void _openMealTabPage(MealTabType tab) {
    final String title = tab.name[0].toUpperCase() + tab.name.substring(1);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeResultsPage(
          title: title,
          initialTab: tab,
          initialQuery: RecipeResultsQuery(mealType: tab.name, sort: 'default'),
          onFavoriteTap: _toggleSaved,
          availableCuisines: _availableCuisines,
          availableMoods: _availableMoods,
          availableDiet: _availableDiet,
          availableTypes: _availableTypes,
          initialCuisines: _selectedCuisines,
          initialMoods: _selectedMoods,
          initialDiet: _selectedDiet,
          initialTypes: _selectedTypes,
        ),
      ),
    );
  }

  List<RecipeCategoryConfig> _visibleCategories(List<Dish> activePool) {
    return _categoryConfigs
        .where(
          (RecipeCategoryConfig c) => _categoryPool(c, activePool).isNotEmpty,
        )
        .toList();
  }

  List<Dish> _categoryPool(
    RecipeCategoryConfig category,
    List<Dish> activePool,
  ) {
    return activePool.where(category.filter).toList();
  }

  List<Dish> _sortedRecipes(List<Dish> pool) {
    final List<Dish> sorted = List<Dish>.from(pool);
    sorted.sort((Dish a, Dish b) {
      final int pop = (b.popular ? 1 : 0) - (a.popular ? 1 : 0);
      if (pop != 0) {
        return pop;
      }
      return b.qualityScore.compareTo(a.qualityScore);
    });
    return sorted;
  }

  List<Dish> _previewRecipes(List<Dish> pool) =>
      _sortedRecipes(pool).take(10).toList();

  void _openCategory(RecipeCategoryConfig category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeResultsPage(
          title: category.title,
          initialQuery: category.query,
          postFilter: category.postFilter,
          onFavoriteTap: _toggleSaved,
          availableCuisines: _availableCuisines,
          availableMoods: _availableMoods,
          availableDiet: _availableDiet,
          availableTypes: _availableTypes,
          initialCuisines: _selectedCuisines,
          initialMoods: _selectedMoods,
          initialDiet: _selectedDiet,
          initialTypes: _selectedTypes,
        ),
      ),
    );
  }

  void _openAllRecipes() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeResultsPage(
          title: 'All Recipes',
          initialQuery: const RecipeResultsQuery(sort: 'default'),
          onFavoriteTap: _toggleSaved,
          availableCuisines: _availableCuisines,
          availableMoods: _availableMoods,
          availableDiet: _availableDiet,
          availableTypes: _availableTypes,
          initialCuisines: _selectedCuisines,
          initialMoods: _selectedMoods,
          initialDiet: _selectedDiet,
          initialTypes: _selectedTypes,
        ),
      ),
    );
  }

  List<Dish> get _filteredDishes {
    return _allDishes.where((Dish dish) {
      final String cuisine = _normalizeLabel(dish.cuisine);
      final String type = _normalizeLabel(dish.type);
      final Set<String> mood = dish.mood
          .map(_normalizeLabel)
          .where((String value) => value.isNotEmpty)
          .toSet();
      final Set<String> diet = dish.diet
          .map(_normalizeLabel)
          .where((String value) => value.isNotEmpty)
          .toSet();

      if (_selectedCuisines.isNotEmpty && !_selectedCuisines.contains(cuisine)) {
        return false;
      }
      if (_selectedMoods.isNotEmpty &&
          mood.intersection(_selectedMoods).isEmpty) {
        return false;
      }
      if (_selectedDiet.isNotEmpty && diet.intersection(_selectedDiet).isEmpty) {
        return false;
      }
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(type)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<RecipeCategoryConfig> get _categoryConfigs => <RecipeCategoryConfig>[
    RecipeCategoryConfig(
      id: 'quick_easy',
      title: 'Quick & Easy',
      assetName: 'Quick & Easy.png',
      query: const RecipeResultsQuery(maxTotalTime: 30, sort: 'cookTime'),
      filter: (Dish d) => d.cookTime > 0 && d.cookTime <= 30,
    ),
    RecipeCategoryConfig(
      id: 'comfort_food',
      title: 'Comfort Food',
      assetName: 'Comfort Food.png',
      query: const RecipeResultsQuery(mood: <String>['comfort']),
      filter: (Dish d) =>
          d.mood.map((e) => e.toLowerCase()).contains('comfort'),
    ),
    RecipeCategoryConfig(
      id: 'healthy_choices',
      title: 'Healthy Choices',
      assetName: 'Healthy Choices.png',
      query: const RecipeResultsQuery(mood: <String>['healthy']),
      filter: (Dish d) {
        final Set<String> mood = d.mood.map((e) => e.toLowerCase()).toSet();
        final String calories = d.calories.trim().toLowerCase();
        return mood.contains('healthy') ||
            calories == 'low' ||
            calories.contains('low');
      },
    ),
    RecipeCategoryConfig(
      id: 'party_snacks',
      title: 'Party Snacks',
      assetName: 'Party Snacks.png',
      query: const RecipeResultsQuery(type: 'snack', mood: <String>['festive']),
      filter: (Dish d) =>
          d.type.toLowerCase() == 'snack' &&
          d.mood.map((e) => e.toLowerCase()).contains('festive'),
    ),
    RecipeCategoryConfig(
      id: 'under_30',
      title: 'Under 30 Minutes',
      assetName: 'Under 30 Minutes.png',
      query: const RecipeResultsQuery(timeTier: 'under_30_minutes', sort: 'cookTime'),
      filter: (Dish d) => d.cookTime > 0 && d.cookTime <= 30,
    ),
    RecipeCategoryConfig(
      id: 'five_ingredients',
      title: '5 Ingredients',
      assetName: '5 Ingredients.png',
      query: const RecipeResultsQuery(maxIngredients: 5),
      postFilter: (Dish d) {
        if (d.sections.isNotEmpty) {
          return d.sections.first.components.length <= 5;
        }
        return d.ingredients.length <= 5;
      },
      filter: (Dish d) {
        if (d.sections.isNotEmpty) {
          return d.sections.first.components.length <= 5;
        }
        return d.ingredients.length <= 5;
      },
    ),
    RecipeCategoryConfig(
      id: 'popular',
      title: 'Most Popular',
      assetName: 'Most Popular.png',
      query: const RecipeResultsQuery(popular: true, sort: 'popular'),
      filter: (Dish d) => d.popular,
    ),
    RecipeCategoryConfig(
      id: 'vegetarian',
      title: 'Vegetarian',
      assetName: 'Vegetarian.png',
      query: const RecipeResultsQuery(diet: <String>['vegetarian']),
      filter: (Dish d) =>
          d.diet.map((e) => e.toLowerCase()).contains('vegetarian'),
    ),
    RecipeCategoryConfig(
      id: 'soups',
      title: 'Soups',
      assetName: 'Soups.png',
      query: const RecipeResultsQuery(type: 'soup'),
      filter: (Dish d) => d.type.toLowerCase() == 'soup',
    ),
    RecipeCategoryConfig(
      id: 'desserts',
      title: 'Desserts',
      assetName: 'Desserts.png',
      query: const RecipeResultsQuery(type: 'dessert'),
      filter: (Dish d) => d.type.toLowerCase() == 'dessert',
    ),
    RecipeCategoryConfig(
      id: 'german',
      title: 'German Favorites',
      assetName: 'German Favourites.png',
      query: const RecipeResultsQuery(cuisine: 'german'),
      filter: (Dish d) => d.cuisine.trim().toLowerCase() == 'german',
    ),
    RecipeCategoryConfig(
      id: 'asian',
      title: 'Asian Flavours',
      assetName: 'Asian Flavours.png',
      query: const RecipeResultsQuery(cuisine: 'asian,japanese'),
      filter: (Dish d) {
        final String cuisine = d.cuisine.toLowerCase();
        return cuisine == 'asian' || cuisine == 'japanese';
      },
    ),
  ];

  List<String> get _availableCuisines =>
      _collectOptions((Dish dish) => <String>[dish.cuisine]);
  List<String> get _availableMoods => _collectOptions((Dish dish) => dish.mood);
  List<String> get _availableDiet => _collectOptions((Dish dish) => dish.diet);
  List<String> get _availableTypes =>
      _collectOptions((Dish dish) => <String>[dish.type]);

  List<String> _collectOptions(List<String> Function(Dish) extractor) {
    final Set<String> values = <String>{};
    for (final Dish dish in _allDishes) {
      for (final String raw in extractor(dish)) {
        final String normalized = _normalizeLabel(raw);
        if (normalized.isNotEmpty) {
          values.add(normalized);
        }
      }
    }
    final List<String> sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  String _normalizeLabel(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final String lower = trimmed.toLowerCase().replaceAll('_', ' ');
    return lower
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .map((String token) => token[0].toUpperCase() + token.substring(1))
        .join(' ');
  }
}

class MealTabsBar extends StatelessWidget {
  const MealTabsBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MealTabType? selected;
  final ValueChanged<MealTabType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 46,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: MealTabType.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, int index) {
            final MealTabType tab = MealTabType.values[index];
            final bool isActive = selected == tab;
            return GestureDetector(
              onTap: () => onSelected(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: kRecipeChipBackgroundColor,
                  borderRadius: BorderRadius.circular(kRecipeChipRadius),
                  border: Border.all(
                    color: isActive ? AppColors.primary : kRecipeChipBorderColor,
                    width: kRecipeChipBorderWidth,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      _iconForTab(tab),
                      size: 18,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _labelForTab(tab),
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _labelForTab(MealTabType tab) {
    switch (tab) {
      case MealTabType.breakfast:
        return 'Breakfast';
      case MealTabType.lunch:
        return 'Lunch';
      case MealTabType.dinner:
        return 'Dinner';
      case MealTabType.snack:
        return 'Snack';
    }
  }

  IconData _iconForTab(MealTabType tab) {
    switch (tab) {
      case MealTabType.breakfast:
        return Icons.free_breakfast;
      case MealTabType.lunch:
        return Icons.lunch_dining;
      case MealTabType.dinner:
        return Icons.dinner_dining;
      case MealTabType.snack:
        return Icons.cookie;
    }
  }
}

class PopularCategoriesGrid extends StatelessWidget {
  const PopularCategoriesGrid({
    super.key,
    required this.categories,
    required this.onTap,
  });

  final List<RecipeCategoryConfig> categories;
  final ValueChanged<RecipeCategoryConfig> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.0,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (_, int index) {
        final RecipeCategoryConfig category = categories[index];
        return GestureDetector(
          onTap: () => onTap(category),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE4DEDB)),
              color: Colors.white,
            ),
            // padding: const EdgeInsets.all(12),
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: _buildCategoryBackground(category)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      category.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: GoogleFonts.nunito(
                        color: const Color.fromARGB(255, 255, 255, 255),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBackground(RecipeCategoryConfig category) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.expand(
        child: Image.asset(
          'assets/media/${category.assetName}',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class RecipeResultsPage extends StatefulWidget {
  const RecipeResultsPage({
    super.key,
    required this.title,
    this.initialTab,
    this.initialQuery = const RecipeResultsQuery(sort: 'default'),
    this.postFilter,
    required this.onFavoriteTap,
    required this.availableCuisines,
    required this.availableMoods,
    required this.availableDiet,
    required this.availableTypes,
    required this.initialCuisines,
    required this.initialMoods,
    required this.initialDiet,
    required this.initialTypes,
  });

  final String title;
  final MealTabType? initialTab;
  final RecipeResultsQuery initialQuery;
  final bool Function(Dish dish)? postFilter;
  final Future<void> Function(Dish) onFavoriteTap;
  final List<String> availableCuisines;
  final List<String> availableMoods;
  final List<String> availableDiet;
  final List<String> availableTypes;
  final Set<String> initialCuisines;
  final Set<String> initialMoods;
  final Set<String> initialDiet;
  final Set<String> initialTypes;

  @override
  State<RecipeResultsPage> createState() => _RecipeResultsPageState();
}

class _RecipeResultsPageState extends State<RecipeResultsPage> {
  static const int _pageSize = 20;

  late MealTabType? _selectedTab = widget.initialTab;
  late Set<String> _selectedCuisines = Set<String>.from(widget.initialCuisines);
  late Set<String> _selectedMoods = Set<String>.from(widget.initialMoods);
  late Set<String> _selectedDiet = Set<String>.from(widget.initialDiet);
  late Set<String> _selectedTypes = Set<String>.from(widget.initialTypes);
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<Dish> _dishes = <Dish>[];
  bool _isSearching = false;
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _error;
  String? _loadMoreError;
  String _query = '';
  int _offset = 0;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirstPage());
  }

  String get _pageTitle {
    if (_selectedTab == null) {
      return widget.title;
    }
    final String name = _selectedTab!.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  bool get _hasActiveSearchOrFilters {
    return _query.trim().isNotEmpty ||
        _selectedCuisines.isNotEmpty ||
        _selectedMoods.isNotEmpty ||
        _selectedDiet.isNotEmpty ||
        _selectedTypes.isNotEmpty;
  }

  Future<void> _loadFirstPage({bool force = false}) async {
    final int generation = ++_requestGeneration;
    setState(() {
      _isInitialLoading = true;
      _error = null;
      _loadMoreError = null;
      _offset = 0;
      _hasMore = false;
      _dishes = <Dish>[];
    });

    try {
      final PaginatedDishesResult page = await _fetchPage(offset: 0, force: force);
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      setState(() {
        _dishes = _applyPostFilter(page.items);
        _offset = page.offset + page.items.length;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      setState(() => _error = ErrorMessages.fromException(e));
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<PaginatedDishesResult> _fetchPage({required int offset, bool force = false}) {
    return context.read<DishRepository>().getDishesPage(
          limit: _pageSize,
          offset: offset,
          search: _query.trim().isEmpty ? null : _query.trim(),
          cuisine: _mergedCsv(widget.initialQuery.cuisine, _selectedCuisines),
          type: _mergedCsv(widget.initialQuery.type, _selectedTypes),
          mealType: _selectedTab?.name ?? widget.initialQuery.mealType,
          mood: _mergedList(widget.initialQuery.mood, _selectedMoods),
          diet: _mergedList(widget.initialQuery.diet, _selectedDiet),
          effort: widget.initialQuery.effort,
          popular: widget.initialQuery.popular,
          maxCookTime: widget.initialQuery.maxCookTime,
          maxTotalTime: widget.initialQuery.maxTotalTime,
          timeTier: widget.initialQuery.timeTier,
          maxIngredients: widget.initialQuery.maxIngredients,
          sort: widget.initialQuery.sort,
          force: force,
        );
  }

  List<Dish> _applyPostFilter(List<Dish> items) {
    final bool Function(Dish dish)? postFilter = widget.postFilter;
    if (postFilter == null) {
      return items;
    }
    return items.where(postFilter).toList();
  }

  List<String>? _mergedList(List<String> base, Set<String> selected) {
    final Set<String> baseValues = base
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final Set<String> selectedValues = selected
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    if (baseValues.isNotEmpty && selectedValues.isNotEmpty) {
      final List<String> intersection = baseValues.intersection(selectedValues).toList();
      return intersection.isEmpty ? <String>['__none__'] : intersection;
    }
    final List<String> values = <String>{...baseValues, ...selectedValues}.toList();
    return values.isEmpty ? null : values;
  }

  String? _mergedCsv(String? base, Set<String> selected) {
    final Set<String> baseValues = (base ?? '')
        .split(',')
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final Set<String> selectedValues = selected
        .map((String value) => value.trim().toLowerCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    if (baseValues.isNotEmpty && selectedValues.isNotEmpty) {
      final Set<String> intersection = baseValues.intersection(selectedValues);
      return intersection.isEmpty ? '__none__' : intersection.join(',');
    }
    final Set<String> values = <String>{...baseValues, ...selectedValues};
    return values.isEmpty ? null : values.join(',');
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }
    final int generation = _requestGeneration;
    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });
    try {
      final PaginatedDishesResult page = await _fetchPage(offset: _offset);
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      final Set<String> existingIds = _dishes.map((Dish dish) => dish.id).toSet();
      final List<Dish> nextItems = _applyPostFilter(page.items)
          .where((Dish dish) => existingIds.add(dish.id))
          .toList();
      setState(() {
        _dishes = <Dish>[..._dishes, ...nextItems];
        _offset = page.offset + page.items.length;
        _hasMore = page.hasMore;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) {
        return;
      }
      setState(() => _loadMoreError = ErrorMessages.fromException(e));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_loadMoreError!),
          action: SnackBarAction(label: 'Retry', onPressed: () => _loadMore()),
        ),
      );
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || _isInitialLoading || _isLoadingMore) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 360) {
      _loadMore();
    }
  }

  void _changeTab(MealTabType tab) {
    setState(() => _selectedTab = tab);
    _loadFirstPage();
  }

  void _toggleSearch() {
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () => _loadFirstPage());
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebounce?.cancel();
    setState(() {
      _query = '';
      _isSearching = false;
    });
    _searchFocusNode.unfocus();
    _loadFirstPage();
  }

  Future<void> _openFilters() async {
    final bool hasFilterOptions = widget.availableCuisines.isNotEmpty ||
        widget.availableMoods.isNotEmpty ||
        widget.availableDiet.isNotEmpty ||
        widget.availableTypes.isNotEmpty;
    if (!hasFilterOptions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filters are coming soon')),
      );
      return;
    }

    final _FilterSelection? next = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _FilterSheet(
          cuisines: widget.availableCuisines,
          moods: widget.availableMoods,
          diet: widget.availableDiet,
          types: widget.availableTypes,
          selectedCuisines: _selectedCuisines,
          selectedMoods: _selectedMoods,
          selectedDiet: _selectedDiet,
          selectedTypes: _selectedTypes,
        ),
      ),
    );

    if (next == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCuisines = Set<String>.from(next.cuisines);
      _selectedMoods = Set<String>.from(next.moods);
      _selectedDiet = Set<String>.from(next.diet);
      _selectedTypes = Set<String>.from(next.types);
    });
    await _loadFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> savedDishIds = context.select<FavoritesProvider, Set<String>>((FavoritesProvider p) => p.savedDishIds);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _RecipeIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _pageTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sectionHeader,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RecipeIconButton(
                        icon: Icons.search,
                        onTap: _toggleSearch,
                        isActive: _isSearching || _query.trim().isNotEmpty,
                      ),
                      const SizedBox(width: 8),
                      _RecipeIconButton(
                        icon: Icons.tune,
                        onTap: _openFilters,
                        isActive: _selectedCuisines.isNotEmpty ||
                            _selectedMoods.isNotEmpty ||
                            _selectedDiet.isNotEmpty ||
                            _selectedTypes.isNotEmpty,
                      ),
                    ],
                  ),
                  if (_isSearching) ...<Widget>[
                    const SizedBox(height: 12),
                    _InlineRecipeSearchField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      onClear: _clearSearch,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: MealTabsBar(selected: _selectedTab, onSelected: _changeTab),
            ),
            Expanded(child: _buildBody(savedDishIds)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Set<String> savedDishIds) {
    if (_isInitialLoading && _dishes.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.84,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const ShimmerCard(),
      );
    }

    if (_error != null && _dishes.isEmpty) {
      return ErrorState(message: _error!, onRetry: () => _loadFirstPage());
    }

    if (_dishes.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadFirstPage(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: 420,
              child: EmptyState(
                icon: Icons.menu_book_outlined,
                title: _hasActiveSearchOrFilters ? 'No recipes found' : 'No dishes in this category',
                subtitle: _hasActiveSearchOrFilters
                    ? 'Try another search or remove filters.'
                    : 'Try another category or reset filters.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFirstPage(force: true),
      child: DishGrid(
        controller: _scrollController,
        dishes: _dishes,
        savedDishIds: savedDishIds,
        onFavoriteTap: widget.onFavoriteTap,
        onDishTap: (Dish dish) => context.push('/recipe-detail/${dish.id}', extra: dish),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

class _RecipeIconButton extends StatelessWidget {
  const _RecipeIconButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kRecipeChipBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRecipeChipRadius),
        side: BorderSide(
          color: isActive ? AppColors.primary : kRecipeChipBorderColor,
          width: kRecipeChipBorderWidth,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRecipeChipRadius),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _InlineRecipeSearchField extends StatelessWidget {
  const _InlineRecipeSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: kRecipeChipBackgroundColor,
        prefixIcon: const Icon(Icons.search, color: Color(0xFF555555), size: 18),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 18),
              ),
        hintText: 'Search any recipe',
        hintStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: const Color(0xFFAAAAAA),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRecipeChipRadius),
          borderSide: const BorderSide(
            color: kRecipeChipBorderColor,
            width: kRecipeChipBorderWidth,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRecipeChipRadius),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: kRecipeChipBorderWidth,
          ),
        ),
      ),
    );
  }
}

class _FavoritesPillButton extends StatelessWidget {
  const _FavoritesPillButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  String get _badgeText => count > 9 ? '9+' : count.toString();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFDCD6D3),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 18,
                height: 18,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    const Center(
                      child: Icon(
                        Icons.bookmark,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _badgeText,
                            style: GoogleFonts.nunito(
                              fontSize: 7,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'My Favorites',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeSearchBar extends StatelessWidget {
  const _RecipeSearchBar({required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kRecipeChipBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRecipeChipRadius),
        side: const BorderSide(
          color: kRecipeChipBorderColor,
          width: kRecipeChipBorderWidth,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRecipeChipRadius),
        onTap: onSearchTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 46,
            child: Row(
              children: <Widget>[
                const Icon(Icons.search, color: Color(0xFF555555), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search any recipe',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFFAAAAAA),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedDishTile extends StatelessWidget {
  const _SavedDishTile({
    required this.dish,
    required this.isSaved,
    required this.onFavoriteTap,
    required this.onOpen,
  });

  final Dish dish;
  final bool isSaved;
  final VoidCallback onFavoriteTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SafeDishImage(
                  imageUrl: ImageUtils.getImageUrl(dish.imageUrl, usage: ImageUsage.dishCard),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dish.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onFavoriteTap,
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: isSaved
                      ? const Color(0xFFFF5D33)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeSearchDelegate extends SearchDelegate<Dish?> {
  _RecipeSearchDelegate({
    required List<Dish> dishes,
    required Set<String> savedDishIds,
    required this.onFavoriteTap,
  }) : _dishes = List<Dish>.from(dishes),
       _savedDishIds = Set<String>.from(savedDishIds);

  final List<Dish> _dishes;
  final Set<String> _savedDishIds;
  final Future<void> Function(Dish) onFavoriteTap;

  @override
  String get searchFieldLabel => 'Search any recipe';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData base = Theme.of(context);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: AppColors.background,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      if (query.isNotEmpty)
        IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final String q = query.trim().toLowerCase();
    final List<Dish> source = q.isEmpty
        ? List<Dish>.from(_dishes)
        : _dishes
            .where((Dish dish) => dish.name.toLowerCase().contains(q))
            .toList();
    final List<Dish> results = List<Dish>.from(source)
      ..sort(
        (Dish a, Dish b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    if (results.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.search_off,
          title: 'No dishes found',
          subtitle: 'Try another dish name',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final Dish dish = results[index];
        return _SavedDishTile(
          dish: dish,
          isSaved: _savedDishIds.contains(dish.id),
          onFavoriteTap: () async {
            await onFavoriteTap(dish);
            if (_savedDishIds.contains(dish.id)) {
              _savedDishIds.remove(dish.id);
            } else {
              _savedDishIds.add(dish.id);
            }
          },
          onOpen: () => close(context, dish),
        );
      },
    );
  }
}

class _FilterSelection {
  const _FilterSelection({
    required this.cuisines,
    required this.moods,
    required this.diet,
    required this.types,
  });

  final Set<String> cuisines;
  final Set<String> moods;
  final Set<String> diet;
  final Set<String> types;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.cuisines,
    required this.moods,
    required this.diet,
    required this.types,
    required this.selectedCuisines,
    required this.selectedMoods,
    required this.selectedDiet,
    required this.selectedTypes,
  });

  final List<String> cuisines;
  final List<String> moods;
  final List<String> diet;
  final List<String> types;
  final Set<String> selectedCuisines;
  final Set<String> selectedMoods;
  final Set<String> selectedDiet;
  final Set<String> selectedTypes;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<String> _cuisines = <String>{...widget.selectedCuisines};
  late final Set<String> _moods = <String>{...widget.selectedMoods};
  late final Set<String> _diet = <String>{...widget.selectedDiet};
  late final Set<String> _types = <String>{...widget.selectedTypes};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Filters',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _FilterGroup(
                        title: 'Cuisine',
                        options: widget.cuisines,
                        selected: _cuisines,
                        onToggle: (v) => _toggle(_cuisines, v),
                      ),
                      _FilterGroup(
                        title: 'Mood',
                        options: widget.moods,
                        selected: _moods,
                        onToggle: (v) => _toggle(_moods, v),
                      ),
                      _FilterGroup(
                        title: 'Diet',
                        options: widget.diet,
                        selected: _diet,
                        onToggle: (v) => _toggle(_diet, v),
                      ),
                      _FilterGroup(
                        title: 'Tags',
                        options: widget.types,
                        selected: _types,
                        onToggle: (v) => _toggle(_types, v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      const _FilterSelection(
                        cuisines: <String>{},
                        moods: <String>{},
                        diet: <String>{},
                        types: <String>{},
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(
                      _FilterSelection(
                        cuisines: _cuisines,
                        moods: _moods,
                        diet: _diet,
                        types: _types,
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (target.contains(value)) {
        target.remove(value);
      } else {
        target.add(value);
      }
    });
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((String option) {
              final bool isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) => onToggle(option),
                showCheckmark: false,
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFFFEFE7),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFE0D8D5),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
