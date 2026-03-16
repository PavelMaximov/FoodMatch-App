import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/image_utils.dart';
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
      return const Center(child: CircularProgressIndicator());
    }

    if (matchProvider.matches.isEmpty) {
      return const Center(child: Text('Пока нет совпадений. Свайпайте вместе!'));
    }

    return ListView.builder(
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(dish.title, style: Theme.of(context).textTheme.titleMedium),
                        Text(dish.cuisine),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: dish.tags.take(3).map((tag) => Chip(label: Text(tag))).toList(),
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
    );
  }
}
