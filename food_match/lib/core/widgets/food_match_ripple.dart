import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';

/// Adds FoodMatch's shared, pointer-positioned ripple and press scale to [child].
class FoodMatchRipple extends StatefulWidget {
  const FoodMatchRipple({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.rippleColor,
    this.tapScale = 0.96,
    this.duration = const Duration(milliseconds: 600),
    this.enabled = true,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? rippleColor;
  final double tapScale;
  final Duration duration;
  final bool enabled;
  final Clip clipBehavior;

  @override
  State<FoodMatchRipple> createState() => _FoodMatchRippleState();
}

class _FoodMatchRippleState extends State<FoodMatchRipple>
    with TickerProviderStateMixin {
  final List<_RippleEntry> _ripples = <_RippleEntry>[];
  bool _pressed = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _startRipple(TapDownDetails details) {
    if (!_interactive) return;
    final AnimationController controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    final _RippleEntry entry = _RippleEntry(details.localPosition, controller);
    controller.addStatusListener((AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      controller.dispose();
      if (mounted) setState(() => _ripples.remove(entry));
    });
    setState(() {
      _pressed = true;
      _ripples.add(entry);
    });
    controller.forward();
  }

  void _release() {
    if (mounted && _pressed) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(covariant FoodMatchRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactive) _release();
  }

  @override
  void dispose() {
    for (final _RippleEntry ripple in _ripples) {
      ripple.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.rippleColor ?? context.fmColors.primaryRipple;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _interactive ? _startRipple : null,
      onTapUp: _interactive ? (_) => _release() : null,
      onTapCancel: _interactive ? _release : null,
      onTap: _interactive ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? widget.tapScale.clamp(0.01, 1.0) : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: widget.borderRadius ?? BorderRadius.zero,
          clipBehavior: widget.clipBehavior,
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              widget.child,
              ..._ripples.map(
                (_RippleEntry ripple) => Positioned.fill(
                  child: IgnorePointer(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final double radius = <double>[
                              (ripple.origin - Offset.zero).distance,
                              (ripple.origin - Offset(constraints.maxWidth, 0))
                                  .distance,
                              (ripple.origin - Offset(0, constraints.maxHeight))
                                  .distance,
                              (ripple.origin -
                                      Offset(
                                        constraints.maxWidth,
                                        constraints.maxHeight,
                                      ))
                                  .distance,
                            ].reduce(math.max);
                            return AnimatedBuilder(
                              animation: ripple.controller,
                              builder: (BuildContext context, Widget? child) {
                                final double progress = Curves.easeOut
                                    .transform(ripple.controller.value);
                                return CustomPaint(
                                  painter: _RipplePainter(
                                    ripple.origin,
                                    radius * progress,
                                    color.withValues(
                                      alpha: color.a * (1 - progress),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RippleEntry {
  const _RippleEntry(this.origin, this.controller);
  final Offset origin;
  final AnimationController controller;
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter(this.origin, this.radius, this.color);
  final Offset origin;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawCircle(origin, radius, Paint()..color = color);

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      radius != oldDelegate.radius ||
      color != oldDelegate.color ||
      origin != oldDelegate.origin;
}
