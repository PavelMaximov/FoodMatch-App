import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/theme_extensions.dart';

class MatchNotificationOverlay extends StatefulWidget {
  const MatchNotificationOverlay({
    required this.dishName,
    required this.onView,
    required this.onDismiss,
    required this.onAutoDismiss,
    super.key,
  });

  static const Duration displayDuration = Duration(seconds: 5);

  final String? dishName;
  final VoidCallback onView;
  final VoidCallback onDismiss;
  final void Function(Rect? heartRect) onAutoDismiss;

  @override
  State<MatchNotificationOverlay> createState() => _MatchNotificationOverlayState();
}

class _MatchNotificationOverlayState extends State<MatchNotificationOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _heartKey = GlobalKey(debugLabel: 'matchSnackbarHeart');
  late final AnimationController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MatchNotificationOverlay.displayDuration,
    )
      ..addStatusListener(_handleStatus)
      ..forward();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted && !_isClosing) {
      _isClosing = true;
      widget.onAutoDismiss(_heartRect());
    }
  }

  Rect? _heartRect() {
    final BuildContext? heartContext = _heartKey.currentContext;
    final RenderObject? renderObject = heartContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final Offset origin = renderObject.localToGlobal(Offset.zero);
      return origin & renderObject.size;
    }
    return null;
  }

  void _handleClose() {
    if (_isClosing) return;
    _isClosing = true;
    widget.onDismiss();
  }

  void _handleView() {
    if (_isClosing) return;
    _isClosing = true;
    widget.onDismiss();
    scheduleMicrotask(widget.onView);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final FoodMatchThemeColors colors = context.fmColors;
    final Color titleColor = isDark ? Colors.white : colors.textPrimary;
    final Color subtitleColor = isDark ? Colors.white.withValues(alpha: 0.78) : colors.textSecondary;
    final Color accentColor = colors.primary;
    final String subtitle = _subtitleFor(widget.dishName);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              height: 92,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: SvgPicture.asset(
                        isDark
                            ? 'assets/ui/match_snackbar_dark.svg'
                            : 'assets/ui/match_snackbar_light.svg',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
                      child: Row(
                        children: <Widget>[
                          Container(
                            key: _heartKey,
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFF7A1A),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/swipe/like_swipe.svg',
                                width: 18,
                                height: 18,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    "It's a match!",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 58,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _handleView,
                                style: TextButton.styleFrom(
                                  foregroundColor: accentColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  minimumSize: const Size(48, 36),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('View'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 2,
                    child: IconButton(
                      onPressed: _handleClose,
                      icon: Icon(Icons.close_rounded, color: subtitleColor, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Close',
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (BuildContext context, Widget? child) {
                          return LinearProgressIndicator(
                            value: 1 - _controller.value,
                            minHeight: 3,
                            backgroundColor: accentColor.withValues(alpha: 0.16),
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitleFor(String? dishName) {
    final String normalized = dishName?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'You both liked a dish.';
    }
    return 'You both liked ${_shortDishName(normalized)}';
  }

  String _shortDishName(String name) {
    final List<String> chars = name.characters.toList();
    if (chars.length <= 10) {
      return name;
    }
    return '${chars.take(10).join()}...';
  }
}

class FlyingMatchHeartOverlay extends StatefulWidget {
  const FlyingMatchHeartOverlay({
    required this.startRect,
    required this.targetRect,
    required this.onComplete,
    super.key,
  });

  final Rect startRect;
  final Rect targetRect;
  final VoidCallback onComplete;

  @override
  State<FlyingMatchHeartOverlay> createState() => _FlyingMatchHeartOverlayState();
}

class _FlyingMatchHeartOverlayState extends State<FlyingMatchHeartOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )
      ..addStatusListener(_handleStatus)
      ..forward();
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Offset start = widget.startRect.center;
    final Offset target = widget.targetRect.center;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _curve,
        builder: (BuildContext context, Widget? child) {
          final double t = _curve.value;
          final Offset linear = Offset.lerp(start, target, t) ?? target;
          final double lift = -72 * math.sin(math.pi * t);
          final Offset center = linear.translate(0, lift);
          final double size = 48 - (18 * t);
          final double opacity = t < 0.76 ? 1 : 1 - ((t - 0.76) / 0.24).clamp(0.0, 1.0);

          return Positioned(
            left: center.dx - (size / 2),
            top: center.dy - (size / 2),
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: 1 - (0.18 * t),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF7A1A),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/swipe/like_swipe.svg',
                      width: size * 0.38,
                      height: size * 0.38,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
