import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  final Future<void> Function(int index, SwipeDirection direction)? onSwipe;
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
  void reset() => _state?._resetInteractionState();
}

class _SwipeableStackState extends State<SwipeableStack>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isAwaitingDeckAdvance = false;
  int _visualDeckOffset = 0;
  Widget? _outgoingCard;
  late final AnimationController _animController;
  Animation<Offset>? _swipeAnimation;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant SwipeableStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }
    // The provider removes the swiped dish only after its request completes.
    // Until then, keep B as the visual top card and A as a separate overlay.
    if (oldWidget.itemCount != widget.itemCount) {
      _visualDeckOffset = 0;
      _isAwaitingDeckAdvance = false;
    }
  }

  @override
  void dispose() { widget.controller?._detach(); _animController.dispose(); super.dispose(); }

  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _cardOpacity => (1 - _dragOffset.dx.abs() / (_screenWidth * .9)).clamp(.65, 1.0);
  double get _labelOpacity => (_dragOffset.dx.abs() / (_screenWidth * .3)).clamp(0.0, 1.0);

  void _resetInteractionState({bool notify = true}) {
    _animController.stop(); _animController.reset();
    void reset() { _dragOffset = Offset.zero; _isDragging = false; _isAwaitingDeckAdvance = false; _visualDeckOffset = 0; _outgoingCard = null; _swipeAnimation = null; _fadeAnimation = null; }
    if (!mounted || !notify) { reset(); return; }
    setState(reset);
  }

  void _onHorizontalDragStart(DragStartDetails _) {
    if (_animController.isAnimating || _isAwaitingDeckAdvance) return;
    setState(() => _isDragging = true);
  }
  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _animController.isAnimating || _isAwaitingDeckAdvance) return;
    setState(() => _dragOffset = Offset(_dragOffset.dx + details.delta.dx, 0));
  }
  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
    final double velocity = details.primaryVelocity ?? 0;
    if (_dragOffset.dx.abs() > _screenWidth * .28 || velocity.abs() > 850) {
      _animateSwipe(_dragOffset.dx > 0 || velocity > 0 ? SwipeDirection.right : SwipeDirection.left);
    } else { _animateSnapBack(); }
  }

  void _animateSwipe(SwipeDirection direction) {
    if (_animController.isAnimating || _isAwaitingDeckAdvance || _visualDeckOffset >= widget.itemCount) return;
    final int outgoingIndex = _visualDeckOffset;
    final int itemCountBeforeSwipe = widget.itemCount;
    _outgoingCard = widget.cardBuilder(context, outgoingIndex);
    _isAwaitingDeckAdvance = true;
    // Promote B before A starts leaving, so the under-card always has its own data and key.
    if (outgoingIndex + 1 < widget.itemCount) _visualDeckOffset++;
    final double targetX = direction == SwipeDirection.right ? _screenWidth * 1.35 : -_screenWidth * 1.35;
    _swipeAnimation = Tween<Offset>(begin: _dragOffset, end: Offset(targetX, 0)).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: _cardOpacity, end: 0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    setState(() {});
    final Future<void>? swipeRequest = widget.onSwipe?.call(outgoingIndex, direction);
    swipeRequest?.whenComplete(() {
      if (!mounted || widget.itemCount != itemCountBeforeSwipe) return;
      // A rejected swipe leaves the provider index unchanged; restore the visual deck.
      setState(() { _visualDeckOffset = 0; _isAwaitingDeckAdvance = false; });
    });
    _animController.forward(from: 0).whenComplete(() { if (mounted) setState(() => _outgoingCard = null); });
  }

  void _animateSnapBack() {
    if (_animController.isAnimating) return;
    _swipeAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: _cardOpacity, end: 1).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward(from: 0).whenComplete(() { if (mounted) setState(() { _dragOffset = Offset.zero; _swipeAnimation = null; _fadeAnimation = null; }); });
  }

  Widget _preview(int index, double scale, double opacity) => Positioned.fill(child: Transform.scale(scale: scale, child: Opacity(opacity: opacity, child: widget.cardBuilder(context, index))));

  @override
  Widget build(BuildContext context) {
    if (_visualDeckOffset >= widget.itemCount) return const SizedBox.shrink();
    final int activeIndex = _visualDeckOffset;
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      if (activeIndex + 2 < widget.itemCount) _preview(activeIndex + 2, .93, .72),
      if (activeIndex + 1 < widget.itemCount) _preview(activeIndex + 1, .96, .88),
      Positioned.fill(child: IgnorePointer(
        ignoring: _isAwaitingDeckAdvance,
        child: GestureDetector(onHorizontalDragStart: _onHorizontalDragStart, onHorizontalDragUpdate: _onHorizontalDragUpdate, onHorizontalDragEnd: _onHorizontalDragEnd, child: widget.cardBuilder(context, activeIndex)),
      )),
      if (_outgoingCard != null) Positioned.fill(child: IgnorePointer(child: AnimatedBuilder(animation: _animController, builder: (BuildContext context, _) {
        final Offset offset = _swipeAnimation?.value ?? _dragOffset;
        final double opacity = _fadeAnimation?.value ?? _cardOpacity;
        return Transform(alignment: Alignment.center, transform: Matrix4.identity()..translateByDouble(offset.dx, 0, 0, 1)..rotateZ((offset.dx / _screenWidth).clamp(-1.0, 1.0) * (pi / 20)), child: Opacity(opacity: opacity, child: Stack(children: <Widget>[_outgoingCard!, if (offset.dx.abs() > 20) Positioned(top: 72, left: 0, right: 0, child: Center(child: Opacity(opacity: _swipeAnimation != null ? 1 : _labelOpacity, child: SvgPicture.asset(offset.dx > 0 ? 'assets/icons/confirmed_swipe.svg' : 'assets/icons/declined_swipe.svg', width: 90, height: 90))))])));
      }))),
    ]);
  }
}
