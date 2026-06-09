import 'package:flutter/material.dart';

import 'safe_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/image_utils.dart';
import '../../data/models/dish.dart';

class DishCompactCard extends StatelessWidget {
  const DishCompactCard({
    super.key,
    required this.dish,
    required this.onTap,
    this.isSaved,
    this.onFavoriteTap,
    this.trailing,
  });

  final Dish dish;
  final VoidCallback onTap;
  final bool? isSaved;
  final VoidCallback? onFavoriteTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEDEBEA)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dish.name.isEmpty ? 'Untitled dish' : dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _buildChips(dish),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: <Widget>[
                        _MetaItem(
                          icon: Icons.access_time,
                          text: '${dish.cookTime <= 0 ? 0 : dish.cookTime} min.',
                        ),
                        _MetaItem(
                          icon: Icons.people_outline,
                          text: '${dish.servings.isEmpty ? '2' : dish.servings} servings',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CompactDishImage(
                imageUrl: dish.imageUrl,
                isBookmarked: isSaved,
                onBookmarkTap: onFavoriteTap,
                trailing: trailing,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChips(Dish dish) {
    final List<String> candidates = <String>[
      dish.cuisine,
      dish.type,
      if (dish.mood.isNotEmpty) dish.mood.first,
    ].where((String value) => value.trim().isNotEmpty).toList();

    if (candidates.isEmpty) {
      candidates.add('Dish');
    }

    return candidates.take(2).map(_TagChip.new).toList();
  }
}

class _CompactDishImage extends StatelessWidget {
  const _CompactDishImage({
    required this.imageUrl,
    this.isBookmarked,
    this.onBookmarkTap,
    this.trailing,
  });

  final String imageUrl;
  final bool? isBookmarked;
  final VoidCallback? onBookmarkTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SafeNetworkImage(
            imageUrl: ImageUtils.getImageUrl(imageUrl, usage: ImageUsage.dishCard),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        if (onBookmarkTap != null && isBookmarked != null)
          Positioned(
            top: 6,
            right: 6,
            child: _ImageActionButton(
              onTap: onBookmarkTap!,
              child: Icon(
                isBookmarked! ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
                color: isBookmarked! ? const Color(0xFFFF5D33) : Colors.white,
              ),
            ),
          ),
        if (trailing != null)
          Positioned(
            top: 6,
            right: 6,
            child: trailing!,
          ),
      ],
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  const _ImageActionButton({
    required this.onTap,
    required this.child,
  });

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: child,
        ),
      ),
    );
  }
}

class DishCompactCardIconButton extends StatelessWidget {
  const DishCompactCardIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.backgroundColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final Color? backgroundColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = _ImageActionButton(
      onTap: onTap,
      child: Icon(icon, size: 16, color: color),
    );

    if (backgroundColor == null && tooltip == null) {
      return button;
    }

    final Widget themedButton = backgroundColor == null
        ? button
        : Material(
            color: backgroundColor,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(icon, size: 16, color: color),
              ),
            ),
          );

    if (tooltip == null) {
      return themedButton;
    }

    return Tooltip(
      message: tooltip!,
      child: themedButton,
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF858585), width: 1.5),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF666666),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          softWrap: true,
          overflow: TextOverflow.visible,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
