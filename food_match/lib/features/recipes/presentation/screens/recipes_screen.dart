import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/repositories/dish_repository.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../shared/widgets/recipe_dish_card.dart';
import '../../../favorites/logic/favorites_provider.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

enum MealTabType { breakfast, lunch, dinner, snack }

bool _matchesToken(String rawValue, String target) {
  final String v = rawValue.trim().toLowerCase();
  if (v.isEmpty) return false;
  if (v == target) return true;
  // split on common separators and whitespace
  final List<String> tokens = v
      .split(RegExp(r'[\s\/,&|]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (tokens.contains(target)) return true;
  // word-boundary match as a fallback
  return RegExp(r'\b' + RegExp.escape(target) + r'\b').hasMatch(v);
}

bool matchesMealTab(Dish dish, MealTabType tab) {
  final Set<String> tags = dish.tags.map((e) => e.trim()).where((s) => s.isNotEmpty).toSet();
  final Set<String> mood = dish.mood.map((e) => e.trim()).where((s) => s.isNotEmpty).toSet();
  final String type = dish.type.trim();
  final String target = tab.name.toLowerCase();

  for (final t in tags) {
    if (_matchesToken(t, target)) return true;
  }
  for (final m in mood) {
    if (_matchesToken(m, target)) return true;
  }
  if (_matchesToken(type, target)) return true;
  return false;
}

class RecipeCategoryConfig {
  const RecipeCategoryConfig({
    required this.id,
    required this.title,
    required this.assetName,
    required this.filter,
  });

  final String id;
  final String title;
  final String assetName;
  final bool Function(Dish dish) filter;
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final DishRepository repository = context.read<DishRepository>();
    try {
      final List<Dish> dishes = await repository.getCatalogDishes();
      await context.read<FavoritesProvider>().loadFavorites();
      if (!mounted) return;
      setState(() => _allDishes = dishes);
      debugPrint('[Recipes] loaded dishes=${dishes.length}');
      final List<List<String>> firstFiveTags = dishes
          .take(5)
          .map((Dish dish) => dish.tags)
          .toList();
      debugPrint('[Recipes] first5.tags=$firstFiveTags');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSaved(Dish dish) async {
    await context.read<FavoritesProvider>().toggleFavorite(dish);
    if (!mounted) return;
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
      if (selected == null || !mounted) return;
      context.push('/recipe-detail/${selected.id}', extra: selected);
    });
  }

  Future<void> _openFilters() async {
    final _FilterSelection? next = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => _FilterSheet(
        cuisines: _availableCuisines,
        moods: _availableMoods,
        diet: _availableDiet,
        types: _availableTypes,
        selectedCuisines: _selectedCuisines,
        selectedMoods: _selectedMoods,
        selectedDiet: _selectedDiet,
        selectedTypes: _selectedTypes,
      ),
    );

    if (next == null || !mounted) return;

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Recipes',
                      style: GoogleFonts.pacifico(
                        fontSize: 36,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      _HeaderIconButton(
                        icon: Icons.bookmark_border,
                        onTap: _openFavorites,
                      ),
                      const SizedBox(width: 8),
                      _HeaderIconButton(icon: Icons.search, onTap: _openSearch),
                      const SizedBox(width: 8),
                      _HeaderIconButton(
                        icon: Icons.tune,
                        onTap: _openFilters,
                        isActive:
                            _selectedCuisines.isNotEmpty ||
                            _selectedMoods.isNotEmpty ||
                            _selectedDiet.isNotEmpty ||
                            _selectedTypes.isNotEmpty,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
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

    final Set<String> savedDishIds = context
        .watch<FavoritesProvider>()
        .savedDishIds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 4, 16, 20),
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
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preview.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, int index) {
                final Dish dish = preview[index];
                return DishCard(
                  dish: dish,
                  isSaved: savedDishIds.contains(dish.id),
                  onFavoriteTap: () => _toggleSaved(dish),
                  onOpen: () => context.push('/recipe-detail/${dish.id}', extra: dish),
                  layout: RecipeDishCardLayout.horizontal,
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  List<Dish> _buildActivePool({required MealTabType? tab}) {
    final List<Dish> basePool = _filteredDishes;
    if (tab == null) return basePool;
    final List<Dish> filtered = basePool
        .where((Dish dish) => matchesMealTab(dish, tab))
        .toList();
    debugPrint(
      '[Recipes] mealTab=${tab.name} all=${basePool.length} filtered=${filtered.length}',
    );
    return filtered;
  }

  void _openMealTabPage(MealTabType tab) {
    final List<Dish> baseDishes = _buildActivePool(tab: null);
    final String title = tab.name[0].toUpperCase() + tab.name.substring(1);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeResultsPage(
          title: title,
          dishes: baseDishes,
          initialTab: tab,
          onFavoriteTap: _toggleSaved,
          onSearchTap: _openSearch,
          onFilterTap: _openFilters,
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
      if (pop != 0) return pop;
      return b.qualityScore.compareTo(a.qualityScore);
    });
    return sorted;
  }

  List<Dish> _previewRecipes(List<Dish> pool) =>
      _sortedRecipes(pool).take(10).toList();

  void _openCategory(RecipeCategoryConfig category) {
    final List<Dish> activePool = _buildActivePool(tab: null);
    final List<Dish> dishes = _sortedRecipes(
      _categoryPool(category, activePool),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeResultsPage(
          title: category.title,
          dishes: dishes,
          onFavoriteTap: _toggleSaved,
          onSearchTap: _openSearch,
          onFilterTap: _openFilters,
        ),
      ),
    );
  }

  void _openAllRecipes() {
    final List<Dish> dishes = _sortedRecipes(_buildActivePool(tab: null));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecipeResultsPage(
          title: 'All Recipes',
          dishes: dishes,
          onFavoriteTap: _toggleSaved,
          onSearchTap: _openSearch,
          onFilterTap: _openFilters,
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

      if (_selectedCuisines.isNotEmpty && !_selectedCuisines.contains(cuisine))
        return false;
      if (_selectedMoods.isNotEmpty &&
          mood.intersection(_selectedMoods).isEmpty)
        return false;
      if (_selectedDiet.isNotEmpty && diet.intersection(_selectedDiet).isEmpty)
        return false;
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(type))
        return false;
      return true;
    }).toList();
  }

  List<RecipeCategoryConfig> get _categoryConfigs => <RecipeCategoryConfig>[
    RecipeCategoryConfig(
      id: 'quick_easy',
      title: 'Quick & Easy',
      assetName: 'Quick & Easy.png',
      filter: (Dish d) =>
          d.effort.trim().toLowerCase() == 'easy' && d.cookTime <= 30,
    ),
    RecipeCategoryConfig(
      id: 'comfort_food',
      title: 'Comfort Food',
      assetName: 'Comfort Food.png',
      filter: (Dish d) =>
          d.mood.map((e) => e.toLowerCase()).contains('comfort'),
    ),
    RecipeCategoryConfig(
      id: 'healthy_choices',
      title: 'Healthy Choices',
      assetName: 'Healthy Choices.png',
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
      filter: (Dish d) =>
          d.type.toLowerCase() == 'snack' &&
          d.mood.map((e) => e.toLowerCase()).contains('festive'),
    ),
    RecipeCategoryConfig(
      id: 'under_30',
      title: 'Under 30 Minutes',
      assetName: 'Under 30 Minutes.png',
      filter: (Dish d) => d.cookTime < 30,
    ),
    RecipeCategoryConfig(
      id: 'five_ingredients',
      title: '5 Ingredients',
      assetName: '5 Ingredients.png',
      filter: (Dish d) {
        if (d.sections.isNotEmpty)
          return d.sections.first.components.length <= 5;
        return d.ingredients.length <= 5;
      },
    ),
    RecipeCategoryConfig(
      id: 'popular',
      title: 'Most Popular',
      assetName: 'Most Popular.png',
      filter: (Dish d) => d.popular,
    ),
    RecipeCategoryConfig(
      id: 'vegetarian',
      title: 'Vegetarian',
      assetName: 'Vegetarian.png',
      filter: (Dish d) =>
          d.diet.map((e) => e.toLowerCase()).contains('vegetarian'),
    ),
    RecipeCategoryConfig(
      id: 'soups',
      title: 'Soups',
      assetName: 'Soups.png',
      filter: (Dish d) => d.type.toLowerCase() == 'soup',
    ),
    RecipeCategoryConfig(
      id: 'desserts',
      title: 'Desserts',
      assetName: 'Desserts.png',
      filter: (Dish d) => d.type.toLowerCase() == 'dessert',
    ),
    RecipeCategoryConfig(
      id: 'german',
      title: 'German Favorites',
      assetName: 'German Favourites.png',
      filter: (Dish d) => d.cuisine.trim().toLowerCase() == 'german',
    ),
    RecipeCategoryConfig(
      id: 'asian',
      title: 'Asian Flavours',
      assetName: 'Asian Flavours.png',
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
        if (normalized.isNotEmpty) values.add(normalized);
      }
    }
    final List<String> sorted = values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  String _normalizeLabel(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return '';
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
    return SizedBox(
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isActive ? AppColors.primary : const Color(0xFFE2DBD8),
                  width: 1.6,
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
    required this.dishes,
    this.initialTab,
    required this.onFavoriteTap,
    required this.onSearchTap,
    required this.onFilterTap,
  });

  final String title;
  final List<Dish> dishes;
  final MealTabType? initialTab;
  final Future<void> Function(Dish) onFavoriteTap;
  final VoidCallback onSearchTap;
  final Future<void> Function() onFilterTap;

  @override
  State<RecipeResultsPage> createState() => _RecipeResultsPageState();
}

class _RecipeResultsPageState extends State<RecipeResultsPage> {
  late MealTabType? _selectedTab = widget.initialTab;

  List<Dish> get _displayedDishes {
    if (_selectedTab == null) return widget.dishes;
    return widget.dishes.where((Dish dish) => matchesMealTab(dish, _selectedTab!)).toList();
  }

  String get _pageTitle {
    if (_selectedTab == null) return widget.title;
    final String name = _selectedTab!.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  void _changeTab(MealTabType tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> savedDishIds = context
        .watch<FavoritesProvider>()
        .savedDishIds;
    final List<Dish> dishes = _displayedDishes;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          _pageTitle,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: widget.onSearchTap,
            icon: const Icon(Icons.search, color: AppColors.textPrimary),
          ),
          IconButton(
            onPressed: widget.onFilterTap,
            icon: const Icon(Icons.tune, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: MealTabsBar(
              selected: _selectedTab,
              onSelected: _changeTab,
            ),
          ),
          Expanded(
            child: dishes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'No recipes found',
                        subtitle: 'Try another meal tab or adjust filters.',
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.84,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: dishes.length,
                    itemBuilder: (_, int index) {
                      final Dish dish = dishes[index];
                      return RecipeDishCard(
                        dish: dish,
                        isSaved: savedDishIds.contains(dish.id),
                        onFavoriteTap: () => widget.onFavoriteTap(dish),
                        onOpen: () => context.push('/recipe-detail/${dish.id}', extra: dish),
                        layout: RecipeDishCardLayout.grid,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
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
      color: isActive ? const Color(0xFFFFEFE7) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.primary : const Color(0xFFE2DBD8),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                child: CachedNetworkImage(
                  imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
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
  }) : _dishes = dishes,
       _savedDishIds = savedDishIds;

  final List<Dish> _dishes;
  final Set<String> _savedDishIds;
  final Future<void> Function(Dish) onFavoriteTap;

  @override
  String get searchFieldLabel => 'Search dishes';

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
    final List<Dish> results =
        q.isEmpty
              ? _dishes
              : _dishes
                    .where((Dish dish) => dish.name.toLowerCase().contains(q))
                    .toList()
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
              'Filter recipes',
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
                  onPressed: () {
                    setState(() {
                      _cuisines.clear();
                      _moods.clear();
                      _diet.clear();
                      _types.clear();
                    });
                  },
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
    if (options.isEmpty) return const SizedBox.shrink();

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
