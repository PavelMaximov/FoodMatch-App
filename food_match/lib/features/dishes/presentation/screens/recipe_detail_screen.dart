import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/assets/app_empty_state_assets.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/dish_image_placeholders.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/models/measurement_system.dart';
import '../../../../data/models/recipe_step.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/media/safe_dish_image.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../favorites/logic/favorites_provider.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../shopping_list/logic/shopping_list_provider.dart';
import '../../domain/ingredient_formatter.dart';
import '../../logic/recipe_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({required this.dishId, this.dish, super.key});

  final String dishId;
  final Dish? dish;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  _RecipeDetailTab _activeTab = _RecipeDetailTab.ingredients;
  bool _isScrolled = false;
  bool _isAddingIngredientsToShoppingList = false;
  bool _hasScheduledShoppingListNavigation = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeProvider>().loadRecipeForDish(
            dishId: widget.dishId,
            dish: widget.dish,
          );
      context.read<FavoritesProvider>().loadFavorites();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final bool nextIsScrolled = _scrollController.hasClients && _scrollController.offset > 80;
    if (nextIsScrolled != _isScrolled) {
      setState(() => _isScrolled = nextIsScrolled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Dish? dish = context.select<RecipeProvider, Dish?>((RecipeProvider p) => p.currentDish);
    final bool isLoading = context.select<RecipeProvider, bool>((RecipeProvider p) => p.isLoading);
    final String? error = context.select<RecipeProvider, String?>((RecipeProvider p) => p.error);
    final FoodMatchThemeColors colors = context.fmColors;
    final MeasurementSystem measurementSystem = resolveMeasurementSystem(
      context.watch<AuthProvider>().measurementSystemPreference,
      locale: Localizations.maybeLocaleOf(context),
    );

    if (isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Padding(
          padding: EdgeInsets.all(AppDimensions.paddingM),
          child: ShimmerCard(),
        ),
      );
    }

    if (error != null && dish == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: ErrorState(
            message: error,
            onRetry: () => context.read<RecipeProvider>().loadRecipeForDish(
                  dishId: widget.dishId,
                  dish: widget.dish,
                ),
          ),
        ),
      );
    }

    if (dish == null) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    AppStrings.recipeNotAvailable,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double heroHeight = math.min(
      math.max(MediaQuery.sizeOf(context).height * 0.40, 280.0),
      380.0,
    );
    final bool isFavorite = context.select<FavoritesProvider, bool>((FavoritesProvider p) => p.savedDishIds.contains(dish.id));
    final bool isFavoriteUpdating = context.select<FavoritesProvider, bool>((FavoritesProvider p) => p.isUpdating(dish.id));

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _HeroImage(dish: dish, dishId: dish.id, height: heroHeight),
              ),
              SliverToBoxAdapter(
                child: _RecipeContent(
                  dish: dish,
                  fallbackDishId: widget.dishId,
                  activeTab: _activeTab,
                  onTabChanged: (_RecipeDetailTab tab) => setState(() => _activeTab = tab),
                  isAddingIngredients: _isAddingIngredientsToShoppingList ||
                      _hasScheduledShoppingListNavigation,
                  onAddIngredients: _handleAddIngredientsToShoppingList,
                  measurementSystem: measurementSystem,
                ),
              ),
            ],
          ),
          _StickyOverlayButtons(
            isScrolled: _isScrolled,
            isFavorite: isFavorite,
            isFavoriteUpdating: isFavoriteUpdating,
            onBackTap: () => Navigator.of(context).pop(),
            onFavoriteTap: () => context.read<FavoritesProvider>().toggleFavorite(dish),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddIngredientsToShoppingList(
    Dish dish,
    List<ShoppingListIngredientInput> ingredients,
  ) async {
    if (_isAddingIngredientsToShoppingList ||
        _hasScheduledShoppingListNavigation) {
      return;
    }
    setState(() => _isAddingIngredientsToShoppingList = true);
    try {
      await context.read<ShoppingListProvider>().addIngredients(
            ingredients: ingredients,
            sourceDishId: dish.id,
            sourceDishName: dish.name,
      );
      if (!mounted) return;
      setState(() => _hasScheduledShoppingListNavigation = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final GoRouter router = GoRouter.of(context);
        if (router.routeInformationProvider.value.uri.path ==
            '/shopping-list') {
          setState(() => _hasScheduledShoppingListNavigation = false);
          return;
        }
        final Future<Object?> navigation = context.pushNamed('shoppingList');
        navigation.whenComplete(() {
          if (!mounted) return;
          setState(() => _hasScheduledShoppingListNavigation = false);
        });
      });
    } finally {
      if (mounted) {
        setState(() => _isAddingIngredientsToShoppingList = false);
      }
    }
  }
}

enum _RecipeDetailTab { ingredients, instructions }

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.dish, required this.dishId, required this.height});

  final Dish dish;
  final String dishId;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Hero(
          tag: 'dish-image-$dishId',
          child: SafeDishImage(
            imageUrl: ImageUtils.getImageUrl(dish.imageUrl, usage: ImageUsage.dishHero),
            fit: BoxFit.cover,
            emptyImageAsset: isCustomDishWithoutPhoto(dish)
                ? AppEmptyStateAssets.customDishPlaceholder
                : null,
          ),
        ),
      ),
    );
  }
}

class _StickyOverlayButtons extends StatelessWidget {
  const _StickyOverlayButtons({
    required this.isScrolled,
    required this.isFavorite,
    required this.isFavoriteUpdating,
    required this.onBackTap,
    required this.onFavoriteTap,
  });

  final bool isScrolled;
  final bool isFavorite;
  final bool isFavoriteUpdating;
  final VoidCallback onBackTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _OverlayCircleButton(
              icon: Icons.arrow_back,
              iconColor: isScrolled ? colors.buttonPrimaryText : colors.textPrimary,
              backgroundColor: isScrolled ? colors.overlay : colors.cardElevated,
              onTap: onBackTap,
            ),
            _OverlayCircleButton(
              icon: isFavorite ? Icons.bookmark : Icons.bookmark_border,
              iconColor: isFavorite
                  ? colors.favoriteActive
                  : isScrolled
                      ? colors.buttonPrimaryText
                      : colors.favoriteInactive,
              backgroundColor: isScrolled ? colors.overlay : colors.cardElevated,
              onTap: isFavoriteUpdating ? null : onFavoriteTap,
              isLoading: isFavoriteUpdating,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayCircleButton extends StatelessWidget {
  const _OverlayCircleButton({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Icon(icon, size: 22, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _RecipeContent extends StatelessWidget {
  const _RecipeContent({
    required this.dish,
    required this.fallbackDishId,
    required this.activeTab,
    required this.onTabChanged,
    required this.isAddingIngredients,
    required this.onAddIngredients,
    required this.measurementSystem,
  });

  final Dish dish;
  final String fallbackDishId;
  final _RecipeDetailTab activeTab;
  final ValueChanged<_RecipeDetailTab> onTabChanged;
  final bool isAddingIngredients;
  final MeasurementSystem measurementSystem;
  final Future<void> Function(
    Dish dish,
    List<ShoppingListIngredientInput> ingredients,
  ) onAddIngredients;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final EdgeInsets safePadding = MediaQuery.paddingOf(context);
    final List<_IngredientDisplayRow> ingredientRows = _buildIngredientRows(dish, measurementSystem);
    final List<ShoppingListIngredientInput> shoppingIngredients =
        _buildShoppingIngredients(dish, measurementSystem);

    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.paddingM,
          26,
          AppDimensions.paddingL,
          safePadding.bottom + AppDimensions.bottomNavHeight + AppDimensions.paddingXL,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              dish.name.isNotEmpty ? dish.name : 'Dish $fallbackDishId',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                height: 1.08,
                color: colors.textPrimary,
              ),
            ),
            if (dish.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                dish.description.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  height: 1.42,
                  color: colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _TagChips(dish: dish),
            const SizedBox(height: 18),
            _StatsRow(dish: dish),
            const SizedBox(height: 24),
            if (shoppingIngredients.isNotEmpty) ...<Widget>[
              TextButton.icon(
                onPressed: isAddingIngredients
                    ? null
                    : () => onAddIngredients(dish, shoppingIngredients),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                icon: isAddingIngredients
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded, size: 21),
                label: Text(
                  'Add ingredients to the grocery list',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _Tabs(activeTab: activeTab, onChanged: onTabChanged),
            _TabPanel(
              child: activeTab == _RecipeDetailTab.ingredients
                  ? _IngredientsContent(rows: ingredientRows)
                  : _InstructionsContent(steps: dish.steps),
            ),
          ],
        ),
      ),
    );
  }

  List<_IngredientDisplayRow> _buildIngredientRows(Dish dish, MeasurementSystem system) {
    final List<_IngredientDisplayRow> structuredRows = dish.sections
        .expand((DishSection section) => section.components)
        .map((DishComponent component) {
          final DishIngredientMeasurement? measurement =
              selectIngredientMeasurement(component.measurements, system);
          return _IngredientDisplayRow(
            name: component.resolvedName,
            measurement: formatIngredientMeasurement(measurement),
          );
        })
        .where((_IngredientDisplayRow row) => row.name.isNotEmpty)
        .toList();

    if (structuredRows.isNotEmpty) {
      return structuredRows;
    }

    return dish.ingredients
        .map((String ingredient) => _IngredientDisplayRow(name: ingredient.trim()))
        .where((_IngredientDisplayRow row) => row.name.isNotEmpty)
        .toList();
  }

  List<ShoppingListIngredientInput> _buildShoppingIngredients(Dish dish, MeasurementSystem system) {
    final List<ShoppingListIngredientInput> richIngredients = dish.sections
        .expand((DishSection section) => section.components)
        .where((DishComponent component) => component.resolvedName.isNotEmpty)
        .map((DishComponent component) {
          final DishIngredientMeasurement? measurement =
              selectIngredientMeasurement(component.measurements, system);
          return ShoppingListIngredientInput(
            name: component.resolvedName,
            quantity: formatIngredientQuantity(measurement?.quantity),
            measure: measurement?.unit,
          );
        })
        .toList();
    if (richIngredients.isNotEmpty) return richIngredients;
    return dish.ingredients
        .map(ShoppingListIngredientInput.fromName)
        .where((ShoppingListIngredientInput ingredient) =>
            ingredient.name.trim().isNotEmpty)
        .toList();
  }
}

class _TagChips extends StatelessWidget {
  const _TagChips({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final List<String> tags = <String>[
      dish.cuisine,
      dish.effort,
      dish.type,
      ...dish.mood,
      ...dish.tags,
    ]
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .take(4)
        .toList();

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: tags.map((String tag) => _TagChip(label: tag)).toList(),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.chipBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          color: colors.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: colors.metadataPillBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _StatItem(icon: Icons.schedule, label: _formatCookTime(dish.cookTime))),
          _VerticalDivider(color: colors.chipBorder),
          Expanded(child: _StatItem(icon: Icons.groups_outlined, label: _formatServings(dish.servings))),
          _VerticalDivider(color: colors.chipBorder),
          Expanded(
            child: _StatItem(
              icon: Icons.local_fire_department_outlined,
              label: _formatCalories(dish),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCookTime(int cookTime) {
    if (cookTime <= 0) return '— min';
    return '$cookTime min';
  }

  String _formatServings(String servings) {
    final String trimmed = servings.trim();
    if (trimmed.isEmpty) {
      return '— servings';
    }
    if (trimmed.toLowerCase().contains(AppStrings.servings)) {
      return trimmed;
    }
    return '$trimmed ${AppStrings.servings}';
  }

  String _formatCalories(Dish dish) {
    final int? numericCalories = dish.nutrition?.calories;
    if (numericCalories != null && numericCalories > 0) {
      return '$numericCalories kcal';
    }

    final String trimmed = dish.calories.trim();
    if (trimmed.isEmpty) {
      return '— kcal';
    }
    if (trimmed.toLowerCase().contains('kcal')) {
      return trimmed;
    }

    final int? parsed = int.tryParse(trimmed);
    if (parsed != null && parsed > 0) {
      return '$parsed kcal';
    }

    return '— kcal';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 17, color: colors.metadataIcon),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: color);
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.activeTab, required this.onChanged});

  final _RecipeDetailTab activeTab;
  final ValueChanged<_RecipeDetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        _TabButton(
          title: AppStrings.ingredients,
          isActive: activeTab == _RecipeDetailTab.ingredients,
          onTap: () => onChanged(_RecipeDetailTab.ingredients),
        ),
        const SizedBox(width: 6),
        _TabButton(
          title: 'Instructions',
          isActive: activeTab == _RecipeDetailTab.instructions,
          onTap: () => onChanged(_RecipeDetailTab.instructions),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.title, required this.isActive, required this.onTap});

  final String title;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Material(
      color: isActive ? colors.buttonPrimaryBackground : colors.cardElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isActive ? colors.buttonPrimaryText : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TabPanel extends StatelessWidget {
  const _TabPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.divider)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: child,
    );
  }
}

class _IngredientDisplayRow {
  const _IngredientDisplayRow({required this.name, this.measurement = ''});

  final String name;
  final String measurement;
}

class _IngredientsContent extends StatelessWidget {
  const _IngredientsContent({required this.rows});

  final List<_IngredientDisplayRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const _InlineEmptyState(
        icon: Icons.shopping_basket_outlined,
        message: 'No ingredients available yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows
          .asMap()
          .entries
          .map(
            (MapEntry<int, _IngredientDisplayRow> entry) => _DashedSeparatedRow(
              showDivider: entry.key < rows.length - 1,
              child: _IngredientText(row: entry.value),
            ),
          )
          .toList(),
    );
  }
}

class _IngredientText extends StatelessWidget {
  const _IngredientText({required this.row});

  final _IngredientDisplayRow row;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    final TextStyle baseStyle = GoogleFonts.nunito(
      fontSize: 14.5,
      height: 1.35,
      color: colors.textPrimary,
    );
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          if (row.measurement.isNotEmpty)
            TextSpan(
              text: '${row.measurement} ',
              style: baseStyle.copyWith(fontWeight: FontWeight.w700),
            ),
          TextSpan(
            text: row.name,
            style: baseStyle.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
      textAlign: TextAlign.start,
    );
  }
}

class _InstructionsContent extends StatelessWidget {
  const _InstructionsContent({required this.steps});

  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    if (steps.isEmpty) {
      return const _InlineEmptyState(
        icon: Icons.menu_book_outlined,
        message: 'No instructions available yet.',
      );
    }

    return Column(
      children: steps.asMap().entries.map((MapEntry<int, RecipeStep> entry) {
        final int stepNumber = entry.value.step > 0 ? entry.value.step : entry.key + 1;
        return _DashedSeparatedRow(
          showDivider: entry.key < steps.length - 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$stepNumber.',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.value.text,
                  style: GoogleFonts.nunito(
                    fontSize: 14.5,
                    height: 1.4,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}


class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: <Widget>[
          Icon(icon, color: colors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedSeparatedRow extends StatelessWidget {
  const _DashedSeparatedRow({required this.child, required this.showDivider});

  final Widget child;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
          if (showDivider) const _DashedDivider(),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashedDividerPainter(context.fmColors.divider)),
    );
  }
}

class _DashedDividerPainter extends CustomPainter {
  const _DashedDividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 5;
    const double dashGap = 4;
    double startX = 0;
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(math.min(startX + dashWidth, size.width), 0), paint);
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedDividerPainter oldDelegate) => oldDelegate.color != color;
}
