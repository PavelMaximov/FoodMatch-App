import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../logic/recipe_provider.dart';

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({required this.dishId, this.dish, super.key});

  final String dishId;
  final Dish? dish;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RecipeProvider>().loadRecipe(widget.dishId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipeProvider = context.watch<RecipeProvider>();
    final recipe = recipeProvider.currentRecipe;

    if (recipeProvider.isLoading) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerCard(),
        ),
      );
    }

    if (recipeProvider.error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(
          message: recipeProvider.error!,
          onRetry: () => context.read<RecipeProvider>().loadRecipe(widget.dishId),
        ),
      );
    }

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Рецепт')),
        body: const EmptyState(
          icon: Icons.menu_book,
          title: 'Рецепт не найден',
          subtitle: 'Для этого блюда рецепт пока недоступен',
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            leading: const BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Рецепт'),
              background: widget.dish != null
                  ? Hero(
                      tag: 'dish-image-${widget.dishId}',
                      child: CachedNetworkImage(
                        imageUrl: ImageUtils.getImageUrl(widget.dish!.imageUrl),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.black12,
                          child: const Icon(Icons.restaurant_menu, size: 72),
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.black12,
                      child: const Icon(Icons.restaurant_menu, size: 72),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.dish?.title ?? 'Блюдо ${widget.dishId}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 8,
                    children: <Widget>[
                      Chip(label: Text('Cuisine')),
                      Chip(label: Text('Recipe')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Ингредиенты', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...recipe.ingredients.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.check, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Приготовление', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ...recipe.steps.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('${entry.key + 1}. '),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  entry.value.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(entry.value.text),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
