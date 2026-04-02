import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../data/models/dish.dart';

class SwipeCardWidget extends StatefulWidget {
  const SwipeCardWidget({
    required this.dish,
    this.onLike,
    this.onDislike,
    this.onBack,
    this.onRefresh,
    this.onConnectSession,
    this.onFilter,
    super.key,
  });

  final Dish dish;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final VoidCallback? onConnectSession;
  final VoidCallback? onFilter;

  @override
  State<SwipeCardWidget> createState() => _SwipeCardWidgetState();
}

class _SwipeCardWidgetState extends State<SwipeCardWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Hero(
            tag: 'dish-image-${widget.dish.id}',
            child: CachedNetworkImage(
              imageUrl: ImageUtils.getImageUrl(widget.dish.imageUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (_, __) => Container(
                color: Colors.grey.shade200,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image, size: 64),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                GestureDetector(
                  onTap: widget.onConnectSession,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                    ),
                    child: Text(
                      AppStrings.connectSession,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onFilter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.tune, size: 16, color: AppColors.textPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Filter',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isExpanded ? 450 : 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState:
                  _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.dish.title,
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildInfoButton(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.dish.description,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _buildTags(),
                ],
              ),
              secondChild: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            widget.dish.title,
                            style: GoogleFonts.nunito(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _buildInfoButton(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.dish.description,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.dish.recipe != null &&
                        widget.dish.recipe!.ingredients.isNotEmpty) ...<Widget>[
                      Text(
                        'Ingredients',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...widget.dish.recipe!.ingredients.take(8).map(
                        (String ing) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• $ing',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _buildTags(),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildCircleButton(
                  size: 44,
                  bgColor: Colors.white.withValues(alpha: 0.15),
                  icon: Icons.chevron_left,
                  iconColor: Colors.white,
                  onTap: widget.onBack,
                ),
                _buildCircleButton(
                  size: 56,
                  bgColor: Colors.white,
                  icon: Icons.close,
                  iconColor: AppColors.textPrimary,
                  onTap: widget.onDislike,
                ),
                _buildCircleButton(
                  size: 64,
                  bgColor: AppColors.primary,
                  icon: Icons.restaurant,
                  iconColor: Colors.white,
                  onTap: widget.onLike,
                ),
                _buildCircleButton(
                  size: 44,
                  bgColor: Colors.white.withValues(alpha: 0.15),
                  icon: Icons.refresh,
                  iconColor: Colors.white,
                  onTap: widget.onRefresh,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoButton() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isExpanded ? AppColors.primary : Colors.white.withValues(alpha: 0.3),
        ),
        child: Icon(
          _isExpanded ? Icons.close : Icons.info_outline,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        if (widget.dish.cuisine.isNotEmpty) _buildTag(widget.dish.cuisine),
        ...widget.dish.tags.take(3).map(_buildTag),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXL),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required double size,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}
