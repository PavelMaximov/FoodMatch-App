import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../../shared/widgets/dish_card_grid.dart';
import '../../logic/favorites_provider.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isSearching = false;
  String _query = '';
  Set<String> _selectedCuisines = <String>{};
  Set<String> _selectedMoods = <String>{};
  Set<String> _selectedDiet = <String>{};

  bool get _hasActiveFilters =>
      _selectedCuisines.isNotEmpty || _selectedMoods.isNotEmpty || _selectedDiet.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFavorites());
  }

  Future<void> _loadFavorites() async {
    await context.read<FavoritesProvider>().loadFavorites(force: true);
  }

  Future<void> _removeFavorite(Dish dish) async {
    await context.read<FavoritesProvider>().toggleFavorite(dish);
    if (!mounted) return;
    final String? error = context.read<FavoritesProvider>().error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _query = '';
      }
    });
  }

  Future<void> _openFilters() async {
    final List<Dish> savedDishes = context.read<FavoritesProvider>().savedDishes;
    final _FavoriteFilterSelection? selection = await showModalBottomSheet<_FavoriteFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => _FavoriteFilterSheet(
        cuisines: _uniqueSorted(savedDishes.map((Dish dish) => dish.cuisine)),
        moods: _uniqueSorted(savedDishes.expand((Dish dish) => dish.mood)),
        diet: _uniqueSorted(savedDishes.expand((Dish dish) => dish.diet)),
        selectedCuisines: _selectedCuisines,
        selectedMoods: _selectedMoods,
        selectedDiet: _selectedDiet,
      ),
    );

    if (selection == null || !mounted) {
      return;
    }

    setState(() {
      _selectedCuisines = selection.cuisines;
      _selectedMoods = selection.moods;
      _selectedDiet = selection.diet;
    });
  }

  List<Dish> _visibleFavorites(List<Dish> favorites) {
    final String query = _query.trim().toLowerCase();
    return favorites.where((Dish dish) {
      if (query.isNotEmpty && !dish.name.toLowerCase().contains(query)) {
        return false;
      }

      final String cuisine = _normalizeLabel(dish.cuisine);
      final Set<String> moods = dish.mood.map(_normalizeLabel).where((String item) => item.isNotEmpty).toSet();
      final Set<String> diet = dish.diet.map(_normalizeLabel).where((String item) => item.isNotEmpty).toSet();

      if (_selectedCuisines.isNotEmpty && !_selectedCuisines.contains(cuisine)) {
        return false;
      }
      if (_selectedMoods.isNotEmpty && moods.intersection(_selectedMoods).isEmpty) {
        return false;
      }
      if (_selectedDiet.isNotEmpty && diet.intersection(_selectedDiet).isEmpty) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    final List<String> labels = values
        .map(_normalizeLabel)
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList();
    labels.sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
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

  @override
  Widget build(BuildContext context) {
    final FavoritesProvider favoritesProvider = context.watch<FavoritesProvider>();
    final List<Dish> visibleFavorites = _visibleFavorites(favoritesProvider.savedDishes);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(19, 16, 19, 0),
              child: _FavoritesHeader(
                isSearching: _isSearching,
                query: _query,
                hasActiveFilters: _hasActiveFilters,
                onQueryChanged: (String value) => setState(() => _query = value),
                onBackTap: context.pop,
                onSearchTap: _toggleSearch,
                onFilterTap: _openFilters,
              ),
            ),
            if (_hasActiveFilters || _query.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 10, 19, 8),
                child: _ResultSummary(
                  count: visibleFavorites.length,
                  onClear: () => setState(() {
                    _query = '';
                    _selectedCuisines = <String>{};
                    _selectedMoods = <String>{};
                    _selectedDiet = <String>{};
                  }),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadFavorites,
                child: _buildBody(favoritesProvider, visibleFavorites),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FavoritesProvider favoritesProvider, List<Dish> visibleFavorites) {
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

    if (favoritesProvider.error != null && favoritesProvider.savedDishes.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          const SizedBox(height: 96),
          ErrorState(message: favoritesProvider.error!, onRetry: _loadFavorites),
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

    return DishCardGrid(
      dishes: dishes,
      crossAxisCount: 2,
      savedDishIds: favoritesProvider.savedDishIds,
      onFavoriteTap: _removeFavorite,
      onDishTap: (Dish dish) => context.push('/recipe-detail/${dish.id}', extra: dish),
      isFavoriteUpdating: favoritesProvider.isUpdating,
      favoriteAlignment: Alignment.topLeft,
      padding: const EdgeInsets.fromLTRB(23, 28, 23, 24),
      mainAxisSpacing: 18,
      crossAxisSpacing: 12,
      childAspectRatio: 0.78,
      physics: const AlwaysScrollableScrollPhysics(),
     
    
    );
  }
}

class _FavoritesHeader extends StatelessWidget {
  const _FavoritesHeader({
    required this.isSearching,
    required this.query,
    required this.hasActiveFilters,
    required this.onQueryChanged,
    required this.onBackTap,
    required this.onSearchTap,
    required this.onFilterTap,
  });

  final bool isSearching;
  final String query;
  final bool hasActiveFilters;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onBackTap;
  final VoidCallback onSearchTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 23, right: 12),
              child: _HeaderIconButton(
                icon: Icons.arrow_back,
                onTap: onBackTap,
              ),
            ),
            Expanded(
              child: Text(
                'Favorites',
                style: GoogleFonts.pacifico(
                  fontSize: 39,
                  height: 1.18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 23),
              child: Row(
                children: <Widget>[
                  _HeaderIconButton(
                    icon: isSearching ? Icons.close : Icons.search,
                    onTap: onSearchTap,
                    isActive: isSearching || query.trim().isNotEmpty,
                  ),
                  const SizedBox(width: 14),
                  _HeaderIconButton(
                    icon: Icons.tune,
                    onTap: onFilterTap,
                    isActive: hasActiveFilters,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isSearching) ...<Widget>[
          const SizedBox(height: 14),
          TextField(
            autofocus: true,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search favorites',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2DBD8)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2DBD8)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ],
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
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
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
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onClear,
          child: const Text('Clear'),
        ),
      ],
    );
  }
}

class _FavoriteFilterSelection {
  const _FavoriteFilterSelection({
    required this.cuisines,
    required this.moods,
    required this.diet,
  });

  final Set<String> cuisines;
  final Set<String> moods;
  final Set<String> diet;
}

class _FavoriteFilterSheet extends StatefulWidget {
  const _FavoriteFilterSheet({
    required this.cuisines,
    required this.moods,
    required this.diet,
    required this.selectedCuisines,
    required this.selectedMoods,
    required this.selectedDiet,
  });

  final List<String> cuisines;
  final List<String> moods;
  final List<String> diet;
  final Set<String> selectedCuisines;
  final Set<String> selectedMoods;
  final Set<String> selectedDiet;

  @override
  State<_FavoriteFilterSheet> createState() => _FavoriteFilterSheetState();
}

class _FavoriteFilterSheetState extends State<_FavoriteFilterSheet> {
  late final Set<String> _cuisines = <String>{...widget.selectedCuisines};
  late final Set<String> _moods = <String>{...widget.selectedMoods};
  late final Set<String> _diet = <String>{...widget.selectedDiet};

  bool get _hasSelections => _cuisines.isNotEmpty || _moods.isNotEmpty || _diet.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(19, 52, 19, 22),
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
              'Filter favorites',
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
                    _FilterSection(
                      title: 'Cuisine',
                      options: widget.cuisines,
                      selected: _cuisines,
                      onChanged: () => setState(() {}),
                    ),
                    _FilterSection(
                      title: 'Mood',
                      options: widget.moods,
                      selected: _moods,
                      onChanged: () => setState(() {}),
                    ),
                    _FilterSection(
                      title: 'Diet',
                      options: widget.diet,
                      selected: _diet,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _hasSelections
                        ? () {
                            setState(() {
                              _cuisines.clear();
                              _moods.clear();
                              _diet.clear();
                            });
                          }
                        : null,
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(
                      _FavoriteFilterSelection(
                        cuisines: <String>{..._cuisines},
                        moods: <String>{..._moods},
                        diet: <String>{..._diet},
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
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
                onSelected: (bool selected) {
                  if (selected) {
                    this.selected.add(option);
                  } else {
                    this.selected.remove(option);
                  }
                  onChanged();
                },
                selectedColor: const Color(0xFFFFDCD0),
                checkmarkColor: AppColors.primary,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2DBD8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
