import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/shimmer_card.dart';
import '../../logic/match_provider.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchProvider>().loadMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final matchProvider = context.watch<MatchProvider>();

    if (matchProvider.isLoading && matchProvider.matches.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ShimmerListTile(),
        ),
      );
    }

    if (matchProvider.error != null && matchProvider.matches.isEmpty) {
      return ErrorState(
        message: matchProvider.error!,
        onRetry: () => context.read<MatchProvider>().loadMatches(),
      );
    }

    if (matchProvider.matches.isEmpty) {
      return const EmptyState(
        icon: Icons.favorite_border,
        title: 'Пока нет совпадений',
        subtitle: 'Свайпайте блюда вместе с партнёром',
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<MatchProvider>().loadMatches(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: matchProvider.matches.length,
        itemBuilder: (context, index) {
          final dish = matchProvider.matches[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/recipe-detail/${dish.id}', extra: dish),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Hero(
                        tag: 'dish-image-${dish.id}',
                        child: CachedNetworkImage(
                          imageUrl: ImageUtils.getImageUrl(dish.imageUrl),
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: Colors.black12,
                            child: SizedBox(
                              width: 80,
                              height: 80,
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            dish.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(dish.cuisine),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: dish.tags
                                .take(3)
                                .map((tag) => Chip(label: Text(tag)))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
