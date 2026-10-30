import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/assets/app_empty_state_assets.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/theme/notification_theme.dart';
import '../../../../core/utils/food_match_notifications.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/repositories/dish_repository.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../shared/widgets/recipe_filter_bottom_sheet.dart';
import '../../../../shared/widgets/recipe_list_chrome.dart';
import '../../../../shared/widgets/dish_grid.dart';
import '../../../favorites/logic/favorites_provider.dart';
import '../../domain/recipe_results_query.dart';
import '../../logic/recipe_results_controller.dart';
import '../../../../shared/logic/recent_searches_controller.dart';

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

  late final MealTabType? _selectedTab = widget.initialTab;
  late final Set<String> _selectedCuisines = Set<String>.from(
    widget.initialCuisines,
  );
  late final Set<String> _selectedMoods = Set<String>.from(widget.initialMoods);
  late final Set<String> _selectedDiet = Set<String>.from(widget.initialDiet);
  late final Set<String> _selectedTypes = Set<String>.from(widget.initialTypes);
  RecipeListFilters _listFilters = const RecipeListFilters();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _isSearching = false;
  String _query = '';
  late final RecipeResultsController _results;
  final _history = RecentSearchesController('recipe_recent_searches');
  List<Dish> get _dishes => _results.items;
  bool get _isInitialLoading => _results.isLoading;
  bool get _isLoadingMore => _results.isLoadingMore;
  String? get _error => _results.error;

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _results.loadMoreError == null) _maybeLoadMore();
    });
  }

  @override
  void initState() {
    super.initState();
    _results = RecipeResultsController(fetchPage: _fetchPage, postFilter: widget.postFilter)
      ..addListener(_onChanged);
    _history.addListener(_onChanged);
    _scrollController.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _history.load();
      _loadFirstPage();
    });
  }

  String get _pageTitle {
    if (_selectedTab == null) {
      return widget.title;
    }
    final String name = _selectedTab.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  bool get _isMealTabPage => widget.initialTab != null;

  bool get _showRecentSearches =>
      !_isMealTabPage && _isSearching && _query.trim().isEmpty;

  bool get _hasActiveSearchOrFilters {
    return _query.trim().isNotEmpty ||
        _selectedCuisines.isNotEmpty ||
        _selectedMoods.isNotEmpty ||
        _selectedDiet.isNotEmpty ||
        _selectedTypes.isNotEmpty ||
        _listFilters.hasActiveFilters;
  }

  Future<void> _loadFirstPage({bool force = false}) {
    _searchDebounce?.cancel();
    return _results.reload(force: force);
  }

  Future<PaginatedDishesResult> _fetchPage({
    required int offset,
    bool force = false,
  }) {
    return context.read<DishRepository>().getDishesPage(
      limit: _pageSize,
      offset: offset,
      search: _query.trim().isEmpty ? null : _query.trim(),
      cuisine: _mergedCsv(widget.initialQuery.cuisine, <String>{
        ..._selectedCuisines,
        ..._listFilters.cuisines,
      }),
      type: _mergedCsv(widget.initialQuery.type, _selectedTypes),
      mealType:
          _selectedTab?.name ??
          _listFilters.mealCategory?.toLowerCase() ??
          widget.initialQuery.mealType,
      mood: _mergedList(widget.initialQuery.mood, _selectedMoods),
      diet: _mergedList(widget.initialQuery.diet, _selectedDiet),
      effort:
          _listFilters.difficulty?.toLowerCase() ?? widget.initialQuery.effort,
      popular: widget.initialQuery.popular,
      maxCookTime: _listFilters.maxCookTime ?? widget.initialQuery.maxCookTime,
      maxTotalTime:
          _listFilters.maxCookTime ?? widget.initialQuery.maxTotalTime,
      timeTier: widget.initialQuery.timeTier,
      maxIngredients: widget.initialQuery.maxIngredients,
      sort: widget.initialQuery.sort,
      force: force,
    );
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
      final List<String> intersection = baseValues
          .intersection(selectedValues)
          .toList();
      return intersection.isEmpty ? <String>['__none__'] : intersection;
    }
    final List<String> values = <String>{
      ...baseValues,
      ...selectedValues,
    }.toList();
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
    await _results.loadMore();
    if (!mounted || _results.loadMoreError == null) return;
    FoodMatchNotifications.show(
      context,
      type: FoodMatchNotificationType.error,
      title: _results.loadMoreError!,
      actionLabel: 'Retry',
      onAction: _loadMore,
    );
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || _isInitialLoading || _isLoadingMore) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (position.extentAfter < position.viewportDimension * 2) {
      _loadMore();
    }
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
    _results.invalidateQuery();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadFirstPage(),
    );
  }

  void _closeOrClearSearch() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      _searchDebounce?.cancel();
      setState(() => _query = '');
      _searchFocusNode.requestFocus();
      _loadFirstPage();
      return;
    }
    _searchDebounce?.cancel();
    setState(() => _isSearching = false);
    _searchFocusNode.unfocus();
    if (_isInitialLoading) _loadFirstPage();
  }

  void _submitSearch(String value) {
    final String query = value.trim();
    if (query.isEmpty) {
      return;
    }
    _history.remember(query);
    _loadFirstPage();
  }

  void _selectRecentSearch(String value) {
    _searchController.text = value;
    _searchController.selection = TextSelection.collapsed(offset: value.length);
    setState(() => _query = value);
    _loadFirstPage();
    _searchFocusNode.requestFocus();
  }

  Future<void> _openFilters() async {
    final RecipeListFilters? next = await showRecipeFilterBottomSheet(
      context: context,
      filters: _listFilters,
      mealOptions: _mealFilterOptions,
      cuisineOptions: widget.availableCuisines,
    );

    if (next == null || !mounted) {
      return;
    }

    setState(() => _listFilters = next);
    await _loadFirstPage();
  }

  List<String> get _mealFilterOptions => const <String>[
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _results.dispose();
    _history.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> savedDishIds = context
        .select<FavoritesProvider, Set<String>>(
          (FavoritesProvider p) => p.savedDishIds,
        );

    return Scaffold(
      backgroundColor: context.fmColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: AppCenteredHeader(
                title: _pageTitle,
                onBackTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            if (!_isMealTabPage) ...<Widget>[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RecipeSearchFilterBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  isActive: _isSearching,
                  hasActiveFilters:
                      _selectedCuisines.isNotEmpty ||
                      _selectedMoods.isNotEmpty ||
                      _selectedDiet.isNotEmpty ||
                      _selectedTypes.isNotEmpty ||
                      _listFilters.hasActiveFilters,
                  onTap: _toggleSearch,
                  onChanged: _onSearchChanged,
                  onSubmitted: _submitSearch,
                  onCloseOrClear: _closeOrClearSearch,
                  onFilterTap: _openFilters,
                ),
              ),
              if (_showRecentSearches)
                RecentSearchBlock(
                  searches: _history.items,
                  onClear: _history.clear,
                  onSelected: _selectRecentSearch,
                ),
            ],
            Expanded(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: _showRecentSearches
                    ? const SizedBox.shrink()
                    : _buildBody(savedDishIds),
              ),
            ),
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
                imageAsset: _hasActiveSearchOrFilters
                    ? AppEmptyStateAssets.emptyRecipesSearch
                    : AppEmptyStateAssets.emptyRecipesCategory,
                title: _hasActiveSearchOrFilters
                    ? 'No recipes found'
                    : 'No dishes in this category',
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
        footer: _isLoadingMore
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _results.loadMoreError != null
                ? Center(child: TextButton(onPressed: _loadMore, child: const Text('Retry loading recipes')))
                : null,
        dishes: _dishes,
        savedDishIds: savedDishIds,
        onFavoriteTap: widget.onFavoriteTap,
        onDishTap: (Dish dish) =>
            context.push('/recipe-detail/${dish.id}', extra: dish),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}
