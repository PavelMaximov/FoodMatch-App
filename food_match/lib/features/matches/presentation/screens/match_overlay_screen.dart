import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';

class MatchOverlayScreen extends StatelessWidget {
  const MatchOverlayScreen({this.dish, super.key});

  final Dish? dish;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  "It's a Match! 🎉",
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                if (dish != null) ...<Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: ImageUtils.getImageUrl(dish!.imageUrl),
                      width: 240,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dish!.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: dish == null ? null : () => context.go('/recipe-detail/${dish!.id}', extra: dish),
                  child: const Text('Посмотреть рецепт'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Продолжить свайпы'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
