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

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  List<Dish> _allDishes = <Dish>[];
  Set<String> _savedDishIds = <String>{};
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
      final List<Dish> dishes = await repository.getDishes();
      final List<Dish> saved = await repository.getSavedDishes();
      if (!mounted) {
        return;
      }
      setState(() {
        _allDishes = dishes;
        _savedDishIds = saved.map((Dish dish) => dish.id).where((String id) => id.isNotEmpty).toSet();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleSaved(String dishId) async {
    if (dishId.isEmpty) {
      return;
    }

    final DishRepository repository = context.read<DishRepository>();
    final bool currentlySaved = _savedDishIds.contains(dishId);

    setState(() {
      if (currentlySaved) {
        _savedDishIds.remove(dishId);
      } else {
        _savedDishIds.add(dishId);
      }
    });

    try {
      if (currentlySaved) {
        await repository.unsaveDish(dishId);
      } else {
        await repository.saveDish(dishId);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (currentlySaved) {
          _savedDishIds.add(dishId);
        } else {
          _savedDishIds.remove(dishId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update favorites. Please try again.')),
      );
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
        savedDishIds: _savedDishIds,
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
                      _HeaderIconButton(icon: Icons.bookmark_border, onTap: _openFavorites),
                      const SizedBox(width: 8),
                      _HeaderIconButton(icon: Icons.search, onTap: _openSearch),
                      const SizedBox(width: 8),
                      _HeaderIconButton(
                        icon: Icons.tune,
                        onTap: _openFilters,
                        isActive: _selectedCuisines.isNotEmpty ||
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
            child: ErrorState(
              message: _error!,
              onRetry: _loadData,
            ),
          ),
        ],
      );
    }

    final Map<String, List<Dish>> grouped = _groupByCuisine(_filteredDishes);
    if (grouped.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 120),
          EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No recipes found',
            subtitle: 'Try clearing filters or searching another dish name',
          ),
        ],
      );
    }

    final List<MapEntry<String, List<Dish>>> sections = grouped.entries.toList()
      ..sort((MapEntry<String, List<Dish>> a, MapEntry<String, List<Dish>> b) =>
          a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: sections.length,
      itemBuilder: (BuildContext context, int index) {
        final MapEntry<String, List<Dish>> section = sections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _CuisineSection(
            title: section.key,
            dishes: section.value,
            savedDishIds: _savedDishIds,
            onFavoriteTap: _toggleSaved,
          ),
        );
      },
    );
  }

  List<Dish> get _filteredDishes {
    return _allDishes.where((Dish dish) {
      final String cuisine = _normalizeLabel(dish.cuisine);
      final String type = _normalizeLabel(dish.type);
      final Set<String> mood = dish.mood.map(_normalizeLabel).where((String value) => value.isNotEmpty).toSet();
      final Set<String> diet = dish.diet.map(_normalizeLabel).where((String value) => value.isNotEmpty).toSet();

      if (_selectedCuisines.isNotEmpty && !_selectedCuisines.contains(cuisine)) {
        return false;
      }
      if (_selectedMoods.isNotEmpty && mood.intersection(_selectedMoods).isEmpty) {
        return false;
      }
      if (_selectedDiet.isNotEmpty && diet.intersection(_selectedDiet).isEmpty) {
        return false;
      }
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(type)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((Dish a, Dish b) {
        final int byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (byName != 0) {
          return byName;
        }
        return a.id.compareTo(b.id);
      });
  }

  List<String> get _availableCuisines => _collectOptions((Dish dish) => <String>[dish.cuisine]);
  List<String> get _availableMoods => _collectOptions((Dish dish) => dish.mood);
  List<String> get _availableDiet => _collectOptions((Dish dish) => dish.diet);
  List<String> get _availableTypes => _collectOptions((Dish dish) => <String>[dish.type]);

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
    final List<String> sorted = values.toList()..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Map<String, List<Dish>> _groupByCuisine(List<Dish> dishes) {
    final Map<String, List<Dish>> grouped = <String, List<Dish>>{};
    for (final Dish dish in dishes) {
      final String cuisine = _normalizeLabel(dish.cuisine);
      final String key = cuisine.isEmpty ? 'Other' : cuisine;
      grouped.putIfAbsent(key, () => <Dish>[]).add(dish);
    }

    for (final List<Dish> group in grouped.values) {
      group.sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return grouped;
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

class _CuisineSection extends StatelessWidget {
  const _CuisineSection({
    required this.title,
    required this.dishes,
    required this.savedDishIds,
    required this.onFavoriteTap,
  });

  final String title;
  final List<Dish> dishes;
  final Set<String> savedDishIds;
  final ValueChanged<String> onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: dishes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (BuildContext context, int index) {
              final Dish dish = dishes[index];
              return _RecipeCard(
                dish: dish,
                isSaved: savedDishIds.contains(dish.id),
                onFavoriteTap: () => onFavoriteTap(dish.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.dish,
    required this.isSaved,
    required this.onFavoriteTap,
  });

  final Dish dish;
  final bool isSaved;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 178,
      child: Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          side: const BorderSide(color: Color(0xFFEDE7E4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  SizedBox(
                    height: 128,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.28),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onFavoriteTap,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            size: 17,
                            color: isSaved ? const Color(0xFFFF5D33) : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dish.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
                      child: Text(
                        'View recipe >',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
        side: BorderSide(color: isActive ? AppColors.primary : const Color(0xFFE2DBD8)),
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
                  maxLines: 2,
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
                  color: isSaved ? const Color(0xFFFF5D33) : AppColors.textSecondary,
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
  })  : _dishes = dishes,
        _savedDishIds = savedDishIds;

  final List<Dish> _dishes;
  final Set<String> _savedDishIds;
  final ValueChanged<String> onFavoriteTap;

  @override
  String get searchFieldLabel => 'Search dishes';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData base = Theme.of(context);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: AppColors.background),
      inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.close),
        ),
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
    final List<Dish> results = q.isEmpty
        ? _dishes
        : _dishes
            .where((Dish dish) => dish.name.toLowerCase().contains(q))
            .toList()
      ..sort((Dish a, Dish b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

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
          onFavoriteTap: () {
            onFavoriteTap(dish.id);
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
                      onToggle: (String value) => _toggle(_cuisines, value),
                    ),
                    _FilterGroup(
                      title: 'Mood',
                      options: widget.moods,
                      selected: _moods,
                      onToggle: (String value) => _toggle(_moods, value),
                    ),
                    _FilterGroup(
                      title: 'Diet',
                      options: widget.diet,
                      selected: _diet,
                      onToggle: (String value) => _toggle(_diet, value),
                    ),
                    _FilterGroup(
                      title: 'Tags',
                      options: widget.types,
                      selected: _types,
                      onToggle: (String value) => _toggle(_types, value),
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
                  onPressed: () {
                    Navigator.of(context).pop(
                      _FilterSelection(
                        cuisines: _cuisines,
                        moods: _moods,
                        diet: _diet,
                        types: _types,
                      ),
                    );
                  },
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
                  color: isSelected ? AppColors.primary : const Color(0xFFE0D8D5),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
