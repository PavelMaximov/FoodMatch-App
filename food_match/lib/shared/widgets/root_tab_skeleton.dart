import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/theme_extensions.dart';

enum RootTabSkeletonType { recipes, matches, swipes, addDish, profile }

class RootTabSkeleton extends StatelessWidget {
  const RootTabSkeleton({super.key, required this.type});

  final RootTabSkeletonType type;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Shimmer.fromColors(
          baseColor: colors.shimmerBase,
          highlightColor: colors.shimmerHighlight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSkeleton(type),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(RootTabSkeletonType type) {
    switch (type) {
      case RootTabSkeletonType.recipes:
        return const _RecipesSkeleton();
      case RootTabSkeletonType.matches:
        return const _MatchesSkeleton();
      case RootTabSkeletonType.swipes:
        return const _SwipesSkeleton();
      case RootTabSkeletonType.addDish:
        return const _AddDishSkeleton();
      case RootTabSkeletonType.profile:
        return const _ProfileSkeleton();
    }
  }
}

class _RecipesSkeleton extends StatelessWidget {
  const _RecipesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        _SkeletonLine(width: 150, height: 32),
        SizedBox(height: 18),
        _SkeletonBox(height: 48, radius: 16),
        SizedBox(height: 18),
        _SkeletonChipRow(count: 4),
        SizedBox(height: 24),
        _SkeletonLine(width: 210, height: 26),
        SizedBox(height: 12),
        _SkeletonGridCards(count: 4, height: 92),
        SizedBox(height: 24),
        _SkeletonLine(width: 160, height: 24),
        SizedBox(height: 12),
        _SkeletonHorizontalCards(count: 3, height: 158),
      ],
    );
  }
}

class _MatchesSkeleton extends StatelessWidget {
  const _MatchesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        _SkeletonLine(width: 150, height: 32),
        SizedBox(height: 10),
        _SkeletonLine(width: 230, height: 16),
        SizedBox(height: 24),
        _SkeletonCard(height: 120),
        SizedBox(height: 14),
        _SkeletonCard(height: 120),
        SizedBox(height: 14),
        _SkeletonCard(height: 120),
      ],
    );
  }
}

class _SwipesSkeleton extends StatelessWidget {
  const _SwipesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _SkeletonCircle(size: 44),
            _SkeletonLine(width: 120, height: 24),
            _SkeletonCircle(size: 44),
          ],
        ),
        SizedBox(height: 28),
        Expanded(child: _SkeletonCard(height: double.infinity, radius: 28)),
        SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _SkeletonCircle(size: 58),
            _SkeletonCircle(size: 72),
            _SkeletonCircle(size: 58),
          ],
        ),
      ],
    );
  }
}

class _AddDishSkeleton extends StatelessWidget {
  const _AddDishSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        _SkeletonLine(width: 170, height: 32),
        SizedBox(height: 18),
        _SkeletonBox(height: 160, radius: 20),
        SizedBox(height: 18),
        _SkeletonBox(height: 52, radius: 14),
        SizedBox(height: 12),
        _SkeletonBox(height: 52, radius: 14),
        SizedBox(height: 12),
        _SkeletonBox(height: 96, radius: 14),
        SizedBox(height: 18),
        _SkeletonChipRow(count: 3),
        SizedBox(height: 24),
        _SkeletonBox(height: 54, radius: 16),
      ],
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const <Widget>[
        Center(child: _SkeletonCircle(size: 96)),
        SizedBox(height: 14),
        Center(child: _SkeletonLine(width: 170, height: 24)),
        SizedBox(height: 28),
        _SkeletonCard(height: 72),
        SizedBox(height: 12),
        _SkeletonCard(height: 72),
        SizedBox(height: 12),
        _SkeletonCard(height: 72),
        SizedBox(height: 24),
        _SkeletonCard(height: 110),
      ],
    );
  }
}

class _SkeletonGridCards extends StatelessWidget {
  const _SkeletonGridCards({required this.count, required this.height});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List<Widget>.generate(
        count,
        (_) => SizedBox(
          width: (MediaQuery.sizeOf(context).width - 44) / 2,
          child: _SkeletonCard(height: height),
        ),
      ),
    );
  }
}

class _SkeletonHorizontalCards extends StatelessWidget {
  const _SkeletonHorizontalCards({required this.count, required this.height});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(
        count,
        (int index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == count - 1 ? 0 : 12),
            child: _SkeletonCard(height: height),
          ),
        ),
      ),
    );
  }
}

class _SkeletonChipRow extends StatelessWidget {
  const _SkeletonChipRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(
        count,
        (int index) => Padding(
          padding: EdgeInsets.only(right: index == count - 1 ? 0 : 8),
          child: const _SkeletonBox(width: 76, height: 38, radius: 14),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height, this.radius = 18});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(height: height, radius: radius);
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(width: width, height: height, radius: height / 2);
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.cardElevated,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final FoodMatchThemeColors colors = context.fmColors;
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: colors.cardElevated,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
