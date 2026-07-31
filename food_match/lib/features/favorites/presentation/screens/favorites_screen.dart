import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/notification_theme.dart';
import '../../../../core/utils/food_match_notifications.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../shared/widgets/dish_grid.dart';
import '../../../../shared/widgets/recipe_filter_bottom_sheet.dart';
import '../../../../shared/widgets/recipe_list_chrome.dart';
import '../../logic/favorites_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isSearching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<String> _recentSearches = <String>[];
  RecipeListFilters _listFilters = const RecipeListFilters();
  List<Dish>? _lastFavoritesInput;
  String? _lastFilterSignature;
  List<Dish> _lastVisibleFavorites = const <Dish>[];

  bool get _hasActiveFilters => _listFilters.hasActiveFilters;

  bool get _showRecentSearches => _isSearching && _query.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentSearches();
      _loadFavorites();
    });
  }

  Future<void> _loadFavorites({bool force = false}) async {
    await context.read<FavoritesProvider>().loadFavorites(force: force);
  }

  Future<void> _removeFavorite(Dish dish) async {
    await context.read<FavoritesProvider>().toggleFavorite(dish);
    if (!mounted) return;
    final String? error = context.read<FavoritesProvider>().error;
    if (error != null) {
      FoodMatchNotifications.show(
        context,
        type: FoodMatchNotificationType.error,
        title: error,
      );
    }
  }

  void _activateSearch() {
    if (_isSearching) {
      return;
    }
    setState(() => _isSearching = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeOrClearSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      setState(() => _query = '');
      _searchFocusNode.requestFocus();
      return;
    }
    setState(() => _isSearching = false);
    _searchFocusNode.unfocus();
  }

  Future<void> _loadRecentSearches() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }
    setState(() {
      _recentSearches
        ..clear()
        ..addAll(
          preferences.getStringList('favorite_recent_searches') ??
              const <String>[],
        );
    });
  }

  Future<void> _saveRecentSearches() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'favorite_recent_searches',
      _recentSearches,
    );
  }

  Future<void> _rememberSearch(String value) async {
    final String query = value.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() {
      _recentSearches.removeWhere(
        (String item) => item.toLowerCase() == query.toLowerCase(),
      );
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches.removeRange(10, _recentSearches.length);
      }
    });
    await _saveRecentSearches();
  }

  void _submitSearch(String value) {
    final String query = value.trim();
    if (query.isEmpty) {
      return;
    }
    _rememberSearch(query);
  }

  void _selectRecentSearch(String value) {
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value);
    _searchFocusNode.requestFocus();
  }

  Future<void> _openFilters() async {
    final List<Dish> savedDishes = context
        .read<FavoritesProvider>()
        .savedDishes;
    final RecipeListFilters? next = await showRecipeFilterBottomSheet(
      context: context,
      filters: _listFilters,
      mealOptions: const <String>['Breakfast', 'Lunch', 'Dinner', 'Snack'],
      cuisineOptions: _uniqueSorted(
        savedDishes.map((Dish dish) => dish.cuisine),
      ),
    );

    if (next == null || !mounted) {
      return;
    }

    setState(() => _listFilters = next);
  }

  List<Dish> _visibleFavorites(List<Dish> favorites) {
    final String query = _query.trim().toLowerCase();
    final String signature = <String>[
      query,
      _listFilters.mealCategory ?? '',
      _listFilters.maxCookTime?.toString() ?? '',
      _listFilters.difficulty ?? '',
      _listFilters.cuisines.join('|'),
    ].join('::');
    if (identical(_lastFavoritesInput, favorites) &&
        _lastFilterSignature == signature) {
      return _lastVisibleFavorites;
    }
    final List<Dish> visible = favorites
        .where((Dish dish) {
          if (query.isNotEmpty && !dish.name.toLowerCase().contains(query)) {
            return false;
          }

          final String cuisine = _normalizeLabel(dish.cuisine);
          if (_listFilters.cuisines.isNotEmpty &&
              !_listFilters.cuisines.contains(cuisine)) {
            return false;
          }
          if (_listFilters.mealCategory != null &&
              !_matchesMealCategory(dish, _listFilters.mealCategory!)) {
            return false;
          }
          if (_listFilters.maxCookTime != null &&
              (dish.cookTime <= 0 ||
                  dish.cookTime > _listFilters.maxCookTime!)) {
            return false;
          }
          if (_listFilters.difficulty != null &&
              !_matchesDifficulty(dish.effort, _listFilters.difficulty!)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    _lastFavoritesInput = favorites;
    _lastFilterSignature = signature;
    _lastVisibleFavorites = visible;
    return visible;
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    final List<String> labels = values
        .map(_normalizeLabel)
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList();
    labels.sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    return labels;
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

  bool _matchesMealCategory(Dish dish, String mealCategory) {
    final String target = mealCategory.trim().toLowerCase();
    final Iterable<String> values = <String>[
      dish.type,
      ...dish.tags,
      ...dish.mood,
    ];
    return values.any((String value) => _matchesToken(value, target));
  }

  bool _matchesToken(String rawValue, String target) {
    final String value = rawValue.trim().toLowerCase();
    if (value.isEmpty) {
      return false;
    }
    if (value == target) {
      return true;
    }
    return value
        .split(RegExp(r'[\s/,&|]+'))
        .map((String token) => token.trim())
        .where((String token) => token.isNotEmpty)
        .contains(target);
  }

  bool _matchesDifficulty(String rawValue, String difficulty) {
    final String value = rawValue.trim().toLowerCase();
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return value == 'easy' || value == 'simple' || value == 'low';
      case 'medium':
        return value == 'medium' || value == 'med' || value == 'moderate';
      case 'hard':
        return value == 'hard' ||
            value == 'complex' ||
            value == 'difficult' ||
            value == 'high';
    }
    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FavoritesProvider favoritesProvider = context
        .watch<FavoritesProvider>();
    final List<Dish> visibleFavorites = _visibleFavorites(
      favoritesProvider.savedDishes,
    );

    return Scaffold(
      backgroundColor: context.fmColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AppCenteredHeader(
                title: 'Favorites',
                onBackTap: () =>
                    context.canPop() ? context.pop() : context.go('/recipes'),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RecipeSearchFilterBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                isActive: _isSearching,
                hasActiveFilters: _hasActiveFilters,
                onTap: _activateSearch,
                onChanged: (String value) => setState(() => _query = value),
                onSubmitted: _submitSearch,
                onCloseOrClear: _closeOrClearSearch,
                onFilterTap: _openFilters,
              ),
            ),
            if (_showRecentSearches)
              RecentSearchBlock(
                searches: _recentSearches,
                onClear: () {
                  setState(_recentSearches.clear);
                  _saveRecentSearches();
                },
                onSelected: _selectRecentSearch,
              ),
            if (_hasActiveFilters || _query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: _ResultSummary(
                  count: visibleFavorites.length,
                  onClear: () => setState(() {
                    _query = '';
                    _searchController.clear();
                    _listFilters = const RecipeListFilters();
                  }),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadFavorites(force: true),
                child: _showRecentSearches
                    ? const SizedBox.shrink()
                    : _buildBody(favoritesProvider, visibleFavorites),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    FavoritesProvider favoritesProvider,
    List<Dish> visibleFavorites,
  ) {
    if (favoritesProvider.isLoading && favoritesProvider.savedDishes.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(19, 18, 19, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 18,
          crossAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const ShimmerCard(),
      );
    }

    if (favoritesProvider.error != null &&
        favoritesProvider.savedDishes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 96),
          ErrorState(
            message: favoritesProvider.error!,
            onRetry: _loadFavorites,
          ),
        ],
      );
    }

    final List<Dish> dishes = visibleFavorites;
    if (favoritesProvider.savedDishes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 120),
          EmptyState(
            icon: Icons.bookmark_border,
            title: 'No saved dishes yet',
            subtitle: 'Bookmark dishes you want to cook later.',
            buttonText: 'Browse recipes',
            onButtonPressed: () => context.go('/recipes'),
          ),
        ],
      );
    }

    if (dishes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.search_off,
            title: 'No dishes found',
            subtitle: 'Try removing some filters or choosing more cuisines.',
          ),
        ],
      );
    }

    return DishGrid(
      dishes: dishes,
      savedDishIds: favoritesProvider.savedDishIds,
      onFavoriteTap: _removeFavorite,
      onDishTap: (Dish dish) =>
          context.push('/recipe-detail/${dish.id}', extra: dish),
      isFavoriteUpdating: favoritesProvider.isUpdating,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      physics: const AlwaysScrollableScrollPhysics(),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          '$count result${count == 1 ? '' : 's'}',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.fmColors.textSecondary,
          ),
        ),
        const Spacer(),
        TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }
}
