import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/dish.dart';

class SwipeCardWidget extends StatelessWidget {
  const SwipeCardWidget({required this.dish, super.key});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CachedNetworkImage(
            imageUrl: dish.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
            errorWidget: (_, __, ___) => const ColoredBox(
              color: Colors.black12,
              child: Center(child: Icon(Icons.image_not_supported_outlined, size: 48)),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color.fromRGBO(0, 0, 0, 0.7)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  dish.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                Text(
                  dish.cuisine,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dish.tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
