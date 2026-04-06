import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

class SwipeableStack extends StatefulWidget {
  const SwipeableStack({
    super.key,
    required this.itemCount,
    required this.cardBuilder,
    this.onSwipe,
    this.controller,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) cardBuilder;
  final void Function(int index, SwipeDirection direction)? onSwipe;
  final SwipeableStackController? controller;

  @override
  State<SwipeableStack> createState() => _SwipeableStackState();
}

enum SwipeDirection { left, right }

class SwipeableStackController {
  _SwipeableStackState? _state;

  void _attach(_SwipeableStackState state) => _state = state;

  void _detach() => _state = null;

  void swipeLeft() => _state?._animateSwipe(SwipeDirection.left);

  void swipeRight() => _state?._animateSwipe(SwipeDirection.right);
}

class _SwipeableStackState extends State<SwipeableStack>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  late final AnimationController _animController;
  Animation<Offset>? _swipeAnimation;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant SwipeableStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _animController.dispose();
    super.dispose();
  }

  double get _rotationAngle {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double normalized = (_dragOffset.dx / screenWidth).clamp(-1.0, 1.0);
    return normalized * (pi / 12);
  }

  double get _cardOpacity {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double progress = _dragOffset.dx.abs() / (screenWidth * 0.5);
    return (1.0 - progress * 0.5).clamp(0.3, 1.0);
  }

  double get _labelOpacity {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double progress = _dragOffset.dx.abs() / (screenWidth * 0.3);
    return progress.clamp(0.0, 1.0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_animController.isAnimating) {
      return;
    }
    setState(() => _isDragging = true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _animController.isAnimating) {
      return;
    }
    setState(() {
      _dragOffset = Offset(
        _dragOffset.dx + details.delta.dx,
        0,
      );
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) {
      return;
    }
    _isDragging = false;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double threshold = screenWidth * 0.3;
    final double velocity = details.primaryVelocity ?? 0;

    if (_dragOffset.dx.abs() > threshold || velocity.abs() > 800) {
      final SwipeDirection direction =
          (_dragOffset.dx > 0 || velocity > 0) ? SwipeDirection.right : SwipeDirection.left;
      _animateSwipe(direction);
    } else {
      _animateSnapBack();
    }
  }

  void _animateSwipe(SwipeDirection direction) {
    if (_animController.isAnimating || widget.itemCount == 0) {
      return;
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double targetX =
        direction == SwipeDirection.right ? screenWidth * 1.5 : -screenWidth * 1.5;

    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(targetX, 0),
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: _cardOpacity,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _animController.forward(from: 0).then((_) {
      if (!mounted) {
        return;
      }
      widget.onSwipe?.call(0, direction);
      setState(() {
        _dragOffset = Offset.zero;
        _swipeAnimation = null;
        _fadeAnimation = null;
      });
      _animController.reset();
    });
  }

  void _animateSnapBack() {
    if (_animController.isAnimating) {
      return;
    }

    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: _cardOpacity,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );

    _animController.forward(from: 0).then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dragOffset = Offset.zero;
        _swipeAnimation = null;
        _fadeAnimation = null;
      });
      _animController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        if (widget.itemCount > 1)
          Positioned.fill(
            child: Transform.scale(
              scale: 0.95,
              child: Opacity(
                opacity: 0.6,
                child: widget.cardBuilder(context, 1),
              ),
            ),
          ),
        Positioned.fill(
          child: GestureDetector(
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (BuildContext context, Widget? child) {
                final Offset offset = _swipeAnimation?.value ?? _dragOffset;
                final double opacity = _fadeAnimation?.value ?? _cardOpacity;
                final double angle = _swipeAnimation != null
                    ? ((offset.dx / MediaQuery.of(context).size.width).clamp(-1.0, 1.0)) *
                        (pi / 12)
                    : _rotationAngle;

                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(offset.dx, offset.dy)
                    ..rotateZ(angle),
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Stack(
                      children: <Widget>[
                        child!,
                        if (offset.dx.abs() > 20)
                          Positioned(
                            top: 72,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Opacity(
                                opacity: _swipeAnimation != null ? 1.0 : _labelOpacity,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: offset.dx > 0 ? AppColors.primary : AppColors.textSecondary,
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    offset.dx > 0 ? 'Like' : 'Dislike',
                                    style: GoogleFonts.nunito(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: offset.dx > 0 ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              child: widget.cardBuilder(context, 0),
            ),
          ),
        ),
      ],
    );
  }
}
