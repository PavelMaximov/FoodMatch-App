import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SwipeableStack extends StatefulWidget {
  const SwipeableStack({
    super.key,
    required this.itemCount,
    required this.cardBuilder,
    required this.canSwipe,
    this.onSwipe,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) cardBuilder;
  final bool canSwipe;
  final void Function(int index, SwipeDirection direction)? onSwipe;

  @override
  SwipeableStackState createState() => SwipeableStackState();
}

enum SwipeDirection { left, right }

enum _ButtonActionOverlay { like, dislike }

class SwipeableStackState extends State<SwipeableStack>
    with TickerProviderStateMixin {
  static const Duration _swipeDuration = Duration(milliseconds: 250);
  static const Duration _buttonSwipeDuration = Duration(milliseconds: 400);
  static const double _distanceThreshold = 120;
  static const double _velocityThreshold = 800;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _didTriggerThresholdHaptic = false;
  bool _isAnimating = false;
  bool _isButtonSwipeAnimating = false;
  int _visualIndex = 0;
  Widget? _outgoingCard;
  late final AnimationController _animationController;
  late final AnimationController _buttonPulseController;
  late final AnimationController _buttonSwipeController;
  late final AnimationController _snapBackController;
  Animation<Offset>? _offsetAnimation;
  Animation<double>? _opacityAnimation;
  _ButtonActionOverlay? _buttonActionOverlay;
  int _buttonPulseGeneration = 0;
  SwipeDirection? _buttonSwipeDirection;
  double _cardAreaWidth = 0;
  Offset _snapBackStartOffset = Offset.zero;

  double _safeDouble(
    double value, {
    double fallback = 0,
    double? min,
    double? max,
  }) {
    if (!value.isFinite) return fallback;
    if (min != null && value < min) return min;
    if (max != null && value > max) return max;
    return value;
  }

  Offset _safeOffset(Offset offset) => Offset(
        _safeDouble(offset.dx),
        _safeDouble(offset.dy),
      );

  void _recoverFromInvalidSwipeState(String reason) {
    if (kDebugMode) debugPrint('[SwipeStack] recovered invalid state reason=$reason');
    _snapBackController.stop();
    _buttonSwipeController.stop();
    if (!mounted) return;
    setState(() {
      _dragOffset = Offset.zero;
      _snapBackStartOffset = Offset.zero;
      _isDragging = false;
      _isAnimating = false;
      _isButtonSwipeAnimating = false;
      _didTriggerThresholdHaptic = false;
      _buttonSwipeDirection = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: _swipeDuration,
    );
    _buttonPulseController = AnimationController(
      vsync: this,
      duration: _buttonSwipeDuration,
    );
    _buttonSwipeController = AnimationController(
      vsync: this,
      duration: _buttonSwipeDuration,
    );
    _snapBackController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        if (!mounted) return;
        final double progress = _snapBackController.value;
        if (!progress.isFinite) {
          _recoverFromInvalidSwipeState('snap_back_progress');
          return;
        }
        final Offset? nextOffset = Offset.lerp(
          _safeOffset(_snapBackStartOffset),
          Offset.zero,
          progress,
        );
        if (nextOffset == null || !nextOffset.dx.isFinite || !nextOffset.dy.isFinite) {
          _recoverFromInvalidSwipeState('snap_back_offset');
          return;
        }
        setState(() {
          _dragOffset = nextOffset;
        });
      });
  }

  @override
  void didUpdateWidget(covariant SwipeableStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Once the provider advances its deck, B becomes index zero in this stack.
    if (oldWidget.itemCount != widget.itemCount && _visualIndex != 0) {
      _visualIndex = 0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonPulseController.dispose();
    _buttonSwipeController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _safeScreenWidth => _safeDouble(_screenWidth, fallback: 1, min: 1);
  double get _rotation => _safeDouble(
        (_safeOffset(_dragOffset).dx / _safeScreenWidth).clamp(-1.0, 1.0) * (pi / 20),
      );
  double get _dragOpacity => _safeDouble(
        1 - _safeOffset(_dragOffset).dx.abs() / (_safeScreenWidth * .9),
        fallback: 1,
        min: .65,
        max: 1,
      );

  Widget _buildDragActionOverlay() {
    final double dragDistance = _safeOffset(_dragOffset).dx.abs();
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
              final double value = Curves.easeInOutCubic.transform(_buttonPulseController.value);
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

  void resetInteractionState() {
    _animationController.stop();
    _animationController.reset();
    _snapBackController.stop();
    _snapBackController.reset();
    if (!mounted) return;
    setState(() {
      _dragOffset = Offset.zero;
      _isDragging = false;
      _didTriggerThresholdHaptic = false;
      _isAnimating = false;
      _isButtonSwipeAnimating = false;
      _buttonSwipeDirection = null;
      _visualIndex = 0;
      _outgoingCard = null;
      _offsetAnimation = null;
      _opacityAnimation = null;
      _buttonActionOverlay = null;
      _buttonPulseGeneration++;
    });
  }

  void _onPanStart(DragStartDetails _) {
    if (_isAnimating || _isButtonSwipeAnimating || !widget.canSwipe) return;
    _buttonPulseController.stop();
    _buttonActionOverlay = null;
    _buttonPulseGeneration++;
    if (kDebugMode) debugPrint('[SwipeAnim] panStart index=$_visualIndex');
    setState(() {
      _isDragging = true;
      _didTriggerThresholdHaptic = false;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isAnimating || _isButtonSwipeAnimating || !widget.canSwipe) return;
    final Offset nextOffset = _safeOffset(Offset(_dragOffset.dx + details.delta.dx, 0));
    if (!_didTriggerThresholdHaptic && nextOffset.dx.abs() >= _distanceThreshold) {
      _didTriggerThresholdHaptic = true;
      unawaited(HapticFeedback.mediumImpact());
      if (kDebugMode) debugPrint('[SwipeAnim] threshold crossed');
    }
    setState(() => _dragOffset = nextOffset);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    _didTriggerThresholdHaptic = false;
    setState(() {});
    final double velocity = _safeDouble(details.primaryVelocity ?? 0);
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
      final double targetDistance = _safeDouble(_cardAreaWidth, fallback: 1, min: 1) * 1.25;
      final double remainingDistance = max(0.0, targetDistance - _dragOffset.dx.abs());
      final double effectiveVelocity = max(velocity.abs(), 900.0);
      final int durationMs = ((remainingDistance / effectiveVelocity) * 1000)
          .round()
          .clamp(160, 440)
          .toInt();
      _startSwipe(
        direction,
        duration: Duration(milliseconds: durationMs),
      );
    }
  }

  void _onPanCancel() {
    if (!_isDragging) return;
    _isDragging = false;
    _didTriggerThresholdHaptic = false;
    setState(() {});
    _animateSnapBack();
  }

  Future<void> swipeRightFromButton() =>
      _runProgrammaticSwipe(SwipeDirection.right);

  Future<void> swipeLeftFromButton() =>
      _runProgrammaticSwipe(SwipeDirection.left);

  Future<void> _runProgrammaticSwipe(SwipeDirection direction) async {
    if (_isDragging || _isAnimating || _isButtonSwipeAnimating || !widget.canSwipe) return;
    final int outgoingIndex = _visualIndex;
    if (kDebugMode) {
      debugPrint('[ButtonSwipe] dedicated start direction=${direction.name} index=$outgoingIndex');
    }
    _buttonSwipeController
      ..stop()
      ..reset();
    setState(() {
      _isButtonSwipeAnimating = true;
      _buttonSwipeDirection = direction;
      _dragOffset = Offset.zero;
    });
    _showButtonActionOverlay(
      direction == SwipeDirection.right
          ? _ButtonActionOverlay.like
          : _ButtonActionOverlay.dislike,
    );
    if (kDebugMode) {
      debugPrint('[ButtonSwipe] controller reset value=${_buttonSwipeController.value.toStringAsFixed(2)}');
    }
    await _buttonSwipeController.animateTo(
      1,
      duration: _buttonSwipeDuration,
      curve: Curves.easeInOutCubic,
    );
    if (!mounted) return;
    if (!_buttonSwipeController.value.isFinite) {
      _recoverFromInvalidSwipeState('button_swipe_value');
      return;
    }
    if (kDebugMode) {
      debugPrint('[ButtonSwipe] dedicated visual complete value=${_buttonSwipeController.value.toStringAsFixed(2)}');
    }
    setState(() {
      if (_visualIndex + 1 < widget.itemCount) {
        _visualIndex++;
      }
      _isButtonSwipeAnimating = false;
      _buttonSwipeDirection = null;
    });
    if (kDebugMode) debugPrint('[ButtonSwipe] callback fired direction=${direction.name}');
    widget.onSwipe?.call(outgoingIndex, direction);
    _buttonSwipeController.reset();
    if (kDebugMode) debugPrint('[ButtonSwipe] cleanup complete buttonOutgoing=false');
  }

  Future<void> _startSwipe(
    SwipeDirection direction, {
    Duration? duration,
  }) {
    if (_isAnimating || _isButtonSwipeAnimating || !widget.canSwipe || _visualIndex >= widget.itemCount) {
      return Future<void>.value();
    }
    final int outgoingIndex = _visualIndex;
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
    return _animationController
        .animateTo(
          1,
          duration: duration ?? _swipeDuration,
          curve: Curves.easeOutCubic,
        )
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

  Future<void> _animateSnapBack() async {
    if (_isAnimating) return;
    _isAnimating = true;
    _snapBackStartOffset = _dragOffset;
    if (kDebugMode) debugPrint('[SwipeAnim] snapBack');
    await _snapBackController.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 30),
        0,
        1,
        0,
      ),
    );
    if (!mounted) return;
    setState(() {
      _dragOffset = Offset.zero;
      _isAnimating = false;
    });
    _snapBackController.reset();
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
    final int baseStartIndex = _visualIndex;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _cardAreaWidth = _safeDouble(constraints.maxWidth, fallback: 1, min: 1);
        if (kDebugMode) {
          debugPrint(
            '[SwipeStack] build deckSize=${widget.itemCount} visualIndex=$_visualIndex '
            'buttonOutgoing=$_isButtonSwipeAnimating '
            'buttonAnimValue=${_buttonSwipeController.value.toStringAsFixed(2)} '
            'baseStartIndex=$baseStartIndex '
            'maxW=${constraints.maxWidth.toStringAsFixed(1)} '
            'maxH=${constraints.maxHeight.toStringAsFixed(1)}',
          );
        }
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: <Widget>[
        if (baseStartIndex + 2 < widget.itemCount) _preview(baseStartIndex + 2, .94, .72),
        if (baseStartIndex + 1 < widget.itemCount) _preview(baseStartIndex + 1, .97, .9),
        if (baseStartIndex < widget.itemCount) Positioned.fill(
          child: IgnorePointer(
            ignoring: _isAnimating || _isButtonSwipeAnimating || !widget.canSwipe,
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onHorizontalDragStart: _onPanStart,
              onHorizontalDragUpdate: _onPanUpdate,
              onHorizontalDragEnd: _onPanEnd,
              onHorizontalDragCancel: _onPanCancel,
              child: AnimatedBuilder(
                animation: _buttonSwipeController,
                builder: (BuildContext context, Widget? child) {
                  final double progress = _safeDouble(
                    Curves.easeInOutCubic.transform(
                      _safeDouble(_buttonSwipeController.value),
                    ),
                    min: 0,
                    max: 1,
                  );
                  final double direction =
                      _buttonSwipeDirection == SwipeDirection.right ? 1.0 : -1.0;
                  final Offset offset = _safeOffset(_isButtonSwipeAnimating
                      ? Offset(
                          direction * _cardAreaWidth * 1.25 * progress,
                          -24 * progress,
                        )
                      : _dragOffset);
                  final double rotation = _safeDouble(
                    _isButtonSwipeAnimating
                        ? direction * (pi / 22.5) * progress
                        : _rotation,
                  );
                  final double opacity = _safeDouble(
                    _isButtonSwipeAnimating ? 1 - (.15 * progress) : _dragOpacity,
                    fallback: 1,
                    min: 0,
                    max: 1,
                  );
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(offset.dx, offset.dy, 0, 1)
                      ..rotateZ(rotation),
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
                child: Stack(
                  children: <Widget>[
                    widget.cardBuilder(context, baseStartIndex),
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
                  final Offset offset = _safeOffset(_offsetAnimation?.value ?? _dragOffset);
                  final double opacity = _safeDouble(
                    _opacityAnimation?.value ?? _dragOpacity,
                    fallback: 1,
                    min: 0,
                    max: 1,
                  );
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(offset.dx, 0, 0, 1)
                      ..rotateZ(_safeDouble((offset.dx / _safeScreenWidth).clamp(-1.0, 1.0) * (pi / 20))),
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
