import '../../../../shared/logic/favorite_actions.dart';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/theme/notification_theme.dart';
import '../../../../core/utils/food_match_notifications.dart';
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
import '../../../../core/utils/logger.dart';
import '../../../../data/models/dish.dart';
import '../../../../data/models/measurement_system.dart';
import '../../../../data/models/recipe_step.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/media/safe_dish_image.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../../favorites/logic/favorites_provider.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../shopping_list/logic/shopping_list_provider.dart';
import '../../../premium/domain/effective_entitlements.dart';
import '../../../premium/domain/premium_entry_point.dart';
import '../../../premium/logic/premium_provider.dart';
import '../../domain/ingredient_display_parser.dart';
import '../../domain/ingredient_formatter.dart';
import '../../logic/recipe_provider.dart';

part '../widgets/recipe_detail_content.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({required this.dishId, this.dish, this.source, super.key});

  final String dishId;
  final Dish? dish;
  final String? source;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  _RecipeDetailTab _activeTab = _RecipeDetailTab.ingredients;
  bool _isScrolled = false;
  bool _isAddingIngredientsToShoppingList = false;
  bool _hasScheduledShoppingListNavigation = false;
  String? _lastDiagnosticSignature;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppLogger.info('[RecipeDetail] open source=${widget.source ?? 'other'} dish=${widget.dishId} initialHasTime=${widget.dish?.hasTime ?? false}');
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
    final preference = context.watch<AuthProvider>().measurementSystemPreference;
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final MeasurementSystem measurementSystem = resolveMeasurementSystem(
      preference: preference, deviceLocale: deviceLocale,
      fallbackLocale: Localizations.maybeLocaleOf(context),
    );
    final diagnostic = '${preference.name}|$deviceLocale|${measurementSystem.name}|${dish?.totalTimeDisplay}';
    if (_lastDiagnosticSignature != diagnostic) {
      _lastDiagnosticSignature = diagnostic;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppLogger.info('[Measurement] preference=${preference.name} locale=$deviceLocale country=${deviceLocale.countryCode ?? 'none'} resolved=${measurementSystem.name}');
        if (dish != null) AppLogger.info('[RecipeDetail] render time=${dish.totalTimeDisplay.isEmpty ? 'none' : dish.totalTimeDisplay} source=${dish.totalTimeMinutes > 0 ? 'totalTimeMinutes' : dish.cookTime > 0 ? 'legacyCookTime' : 'componentOrTier'}');
      });
    }

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
            onFavoriteTap: () => toggleDishFavorite(context, dish),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddIngredientsToShoppingList(
    Dish dish,
    List<ShoppingListIngredientInput> ingredients,
  ) async {
    final premium=context.read<PremiumProvider>();
    if(!premium.canUse(PremiumFeature.shoppingList)&&!premium.canUse(PremiumFeature.sharedShoppingList)){
      await context.push('/profile/premium',extra:PremiumEntryPoint.shoppingList);
      return;
    }
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
    } catch (error) {
      if (mounted) {
        FoodMatchNotifications.show(context,
          type: FoodMatchNotificationType.error,
          title: ErrorMessages.fromException(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingIngredientsToShoppingList = false);
      }
    }
  }
}
