import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuthStaggeredEntrance extends StatefulWidget {
  const AuthStaggeredEntrance({
    super.key,
    required this.children,
    this.initialDelay = const Duration(milliseconds: 320),
    this.itemDelay = const Duration(milliseconds: 80),
    this.itemDuration = const Duration(milliseconds: 550),
  });

  final List<Widget> children;
  final Duration initialDelay;
  final Duration itemDelay;
  final Duration itemDuration;

  @override
  State<AuthStaggeredEntrance> createState() => _AuthStaggeredEntranceState();
}

class _AuthStaggeredEntranceState extends State<AuthStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration())
      ..forward();
  }

  Duration _totalDuration() {
    if (widget.children.isEmpty) return widget.itemDuration;
    return widget.initialDelay +
        (widget.itemDelay * math.max(0, widget.children.length - 1)) +
        widget.itemDuration;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int itemCount = widget.children.length;
    final int totalMs = math.max(1, _controller.duration!.inMilliseconds);
    final int initialDelayMs = widget.initialDelay.inMilliseconds;
    final int itemDelayMs = widget.itemDelay.inMilliseconds;
    final int itemDurationMs = widget.itemDuration.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List<Widget>.generate(itemCount, (int index) {
        final double start = ((initialDelayMs + itemDelayMs * index) / totalMs)
            .clamp(0.0, 1.0)
            .toDouble();
        final double end = ((initialDelayMs + itemDelayMs * index +
                    itemDurationMs) /
                totalMs)
            .clamp(start, 1.0)
            .toDouble();
        final Animation<double> curved = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );
        final Animation<Offset> offset = Tween<Offset>(
          begin: const Offset(0, 0.075),
          end: Offset.zero,
        ).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(position: offset, child: widget.children[index]),
        );
      }),
    );
  }
}
