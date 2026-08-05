import 'dart:math' as math;

import 'package:flutter/material.dart';

class OnboardingProgressButton extends StatelessWidget {
  const OnboardingProgressButton({
    super.key,
    required this.progress,
    required this.onPressed,
    required this.semanticProgress,
  });

  final double progress;
  final VoidCallback onPressed;
  final String semanticProgress;

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFFFF7A4D);
    return Semantics(
      label: semanticProgress,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: progress.clamp(0, 1)),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double animatedProgress, Widget? child) {
          return SizedBox.square(
            dimension: 76,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress: animatedProgress,
                color: accent,
              ),
              child: Center(child: child),
            ),
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 58,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - 5) / 2;
    final Paint trackPaint = Paint()
      ..color = color.withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final Paint progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
