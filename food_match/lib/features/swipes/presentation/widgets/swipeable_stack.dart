import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SwipeableStack extends StatefulWidget {
  const SwipeableStack({
    super.key,
    required this.itemCount,
    required this.cardBuilder,
    required this.canSwipe,
    this.onSwipe,
    this.controller,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) cardBuilder;
  final bool canSwipe;
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
  void swipeLeft() => _state?._startSwipe(SwipeDirection.left, showButtonOverlay: true);
  void swipeRight() => _state?._startSwipe(SwipeDirection.right, showButtonOverlay: true);
  void reset() => _state?._resetInteractionState();
}

enum _ButtonActionOverlay { like, dislike }

class _SwipeableStackState extends State<SwipeableStack>
    with TickerProviderStateMixin {
  static const Duration _swipeDuration = Duration(milliseconds: 250);
  static const Duration _snapBackDuration = Duration(milliseconds: 180);
  static const double _distanceThreshold = 120;
  static const double _velocityThreshold = 800;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isAnimating = false;
  int _visualIndex = 0;
  Widget? _outgoingCard;
  late final AnimationController _animationController;
  late final AnimationController _buttonPulseController;
  Animation<Offset>? _offsetAnimation;
  Animation<double>? _opacityAnimation;
  _ButtonActionOverlay? _buttonActionOverlay;
  int _buttonPulseGeneration = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _buttonPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 330),
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
    // Once the provider advances its deck, B becomes index zero in this stack.
    if (oldWidget.itemCount != widget.itemCount && _visualIndex != 0) {
      _visualIndex = 0;
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _animationController.dispose();
    _buttonPulseController.dispose();
    super.dispose();
  }

  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _rotation =>
      (_dragOffset.dx / _screenWidth).clamp(-1.0, 1.0) * (pi / 20);
  double get _dragOpacity =>
      (1 - _dragOffset.dx.abs() / (_screenWidth * .9)).clamp(.65, 1.0);

  Widget _buildDragActionOverlay() {
    final double dragDistance = _dragOffset.dx.abs();
    final double progress = (dragDistance / _distanceThreshold).clamp(0.0, 1.0);
    final double normalized = _isDragging && dragDistance >= 12
        ? ((progress - .08) / .67).clamp(0.0, 1.0)
        : 0.0;

    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: normalized,
            child: Transform.scale(
              scale: .75 + (.4 * normalized),
              child: SvgPicture.asset(
                _dragOffset.dx < 0
                    ? 'assets/icons/declined_swipe.svg'
                    : 'assets/icons/confirmed_swipe.svg',
                width: 90,
                height: 90,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonActionOverlay() {
    final _ButtonActionOverlay? action = _buttonActionOverlay;
    if (action == null) return const SizedBox.shrink();

    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _buttonPulseController,
            builder: (BuildContext context, Widget? child) {
              final double value = Curves.easeOutCubic.transform(_buttonPulseController.value);
              final double opacity = value < .6 ? value / .6 : (1 - value) / .4;
              final double scale = value < .6
                  ? .75 + (.4 * (value / .6))
                  : 1.15 - (.2 * ((value - .6) / .4));
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: SvgPicture.asset(
              action == _ButtonActionOverlay.like
                  ? 'assets/icons/confirmed_swipe.svg'
                  : 'assets/icons/declined_swipe.svg',
              width: 90,
              height: 90,
            ),
          ),
        ),
      ),
    );
  }

  void _showButtonActionOverlay(_ButtonActionOverlay action) {
    final int generation = ++_buttonPulseGeneration;
    setState(() => _buttonActionOverlay = action);
    _buttonPulseController.forward(from: 0).whenComplete(() {
      if (mounted && !_isDragging && generation == _buttonPulseGeneration) {
        setState(() => _buttonActionOverlay = null);
      }
    });
  }

  void _resetInteractionState() {
    _animationController.stop();
    _animationController.reset();
    if (!mounted) return;
    setState(() {
      _dragOffset = Offset.zero;
      _isDragging = false;
      _isAnimating = false;
      _visualIndex = 0;
      _outgoingCard = null;
      _offsetAnimation = null;
      _opacityAnimation = null;
      _buttonActionOverlay = null;
      _buttonPulseGeneration++;
    });
  }

  void _onPanStart(DragStartDetails _) {
    if (_isAnimating || !widget.canSwipe) return;
    _buttonPulseController.stop();
    _buttonActionOverlay = null;
    _buttonPulseGeneration++;
    if (kDebugMode) debugPrint('[SwipeAnim] panStart index=$_visualIndex');
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating || !widget.canSwipe) return;
    setState(() => _dragOffset = Offset(_dragOffset.dx + details.delta.dx, 0));
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    setState(() {});
    final double velocity = details.primaryVelocity ?? 0;
    final bool crossedDistance = _dragOffset.dx.abs() >= _distanceThreshold;
    final bool crossedVelocity = velocity.abs() >= _velocityThreshold &&
        (_dragOffset.dx.abs() >= 12 || velocity.abs() >= _velocityThreshold);
    final bool accepted = crossedDistance || crossedVelocity;
    final SwipeDirection? direction = !accepted
        ? null
        : (_dragOffset.dx < 0 || velocity < 0)
            ? SwipeDirection.left
            : SwipeDirection.right;
    if (kDebugMode) {
      debugPrint(
        '[SwipeAnim] panEnd dx=${_dragOffset.dx.toStringAsFixed(1)} '
        'vx=${velocity.toStringAsFixed(1)} accepted=$accepted '
        'direction=${direction?.name ?? 'none'}',
      );
    }
    if (direction == null) {
      _animateSnapBack();
    } else {
      _startSwipe(direction);
    }
  }

  void _onPanCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    setState(() {});
    _animateSnapBack();
  }

  void _startSwipe(SwipeDirection direction, {bool showButtonOverlay = false}) {
    if (_isAnimating || !widget.canSwipe || _visualIndex >= widget.itemCount) {
      return;
    }
    final int outgoingIndex = _visualIndex;
    if (showButtonOverlay) {
      _showButtonActionOverlay(
        direction == SwipeDirection.right
            ? _ButtonActionOverlay.like
            : _ButtonActionOverlay.dislike,
      );
    }
    final double targetX = direction == SwipeDirection.left
        ? -_screenWidth * 1.25
        : _screenWidth * 1.25;
    _outgoingCard = widget.cardBuilder(context, outgoingIndex);
    _isAnimating = true;
    if (outgoingIndex + 1 < widget.itemCount) {
      _visualIndex++;
    }
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(targetX, 0),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _opacityAnimation = Tween<double>(begin: _dragOpacity, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    if (kDebugMode) {
      debugPrint('[SwipeAnim] swipeOut start index=$outgoingIndex direction=${direction.name}');
    }
    _dragOffset = Offset.zero;
    setState(() {});
    widget.onSwipe?.call(outgoingIndex, direction);
    _animationController
        .animateTo(1, duration: _swipeDuration, curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (!mounted) return;
      if (kDebugMode) debugPrint('[SwipeAnim] swipeOut complete');
      setState(() {
        _dragOffset = Offset.zero;
        _isAnimating = false;
        _outgoingCard = null;
        _offsetAnimation = null;
        _opacityAnimation = null;
      });
      _animationController.reset();
    });
  }

  void _animateSnapBack() {
    if (_isAnimating) return;
    _isAnimating = true;
    _offsetAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _opacityAnimation = Tween<double>(begin: _dragOpacity, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    if (kDebugMode) debugPrint('[SwipeAnim] snapBack');
    _animationController
        .animateTo(1, duration: _snapBackDuration, curve: Curves.easeOutCubic)
        .whenComplete(() {
      if (!mounted) return;
      setState(() {
        _dragOffset = Offset.zero;
        _isAnimating = false;
        _offsetAnimation = null;
        _opacityAnimation = null;
      });
      _animationController.reset();
    });
  }

  Widget _preview(int index, double scale, double opacity) => Positioned.fill(
        child: Transform.scale(
          scale: scale,
          child: Opacity(opacity: opacity, child: widget.cardBuilder(context, index)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_visualIndex >= widget.itemCount) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (kDebugMode) {
          debugPrint(
            '[SwipeStack] build deckSize=${widget.itemCount} visualIndex=$_visualIndex '
            'maxW=${constraints.maxWidth.toStringAsFixed(1)} '
            'maxH=${constraints.maxHeight.toStringAsFixed(1)}',
          );
        }
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
        if (_visualIndex + 2 < widget.itemCount) _preview(_visualIndex + 2, .94, .72),
        if (_visualIndex + 1 < widget.itemCount) _preview(_visualIndex + 1, .97, .9),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _isAnimating || !widget.canSwipe,
            child: GestureDetector(
              onHorizontalDragStart: _onPanStart,
              onHorizontalDragUpdate: _onPanUpdate,
              onHorizontalDragEnd: _onPanEnd,
              onHorizontalDragCancel: _onPanCancel,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translateByDouble(_dragOffset.dx, 0, 0, 1)
                  ..rotateZ(_rotation),
                child: Stack(
                  children: <Widget>[
                    Opacity(
                      opacity: _dragOpacity,
                      child: widget.cardBuilder(context, _visualIndex),
                    ),
                    _buildDragActionOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_outgoingCard != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (BuildContext context, Widget? _) {
                  final Offset offset = _offsetAnimation?.value ?? _dragOffset;
                  final double opacity = _opacityAnimation?.value ?? _dragOpacity;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(offset.dx, 0, 0, 1)
                      ..rotateZ((offset.dx / _screenWidth).clamp(-1.0, 1.0) * (pi / 20)),
                    child: Opacity(
                      opacity: opacity,
                      child: _outgoingCard!,
                    ),
                  );
                },
              ),
            ),
          ),
            _buildButtonActionOverlay(),
          ],
        );
      },
    );
  }
}
