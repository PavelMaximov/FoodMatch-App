import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/theme_extensions.dart';

class FoodMatchSvgLoader extends StatefulWidget {
  const FoodMatchSvgLoader({
    super.key,
    this.size = 72,
    this.label,
    this.dimmed = false,
  });

  final double size;
  final String? label;
  final bool dimmed;

  @override
  State<FoodMatchSvgLoader> createState() => _FoodMatchSvgLoaderState();
}

class _FoodMatchSvgLoaderState extends State<FoodMatchSvgLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0.96, end: 1.04)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.04, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
    _controller.repeat();
    debugPrint('[Loader] waitingJsonReplaced=true');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        widget.dimmed ? Colors.white : context.fmColors.textPrimary;
    return TickerMode(
      enabled: TickerMode.of(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ScaleTransition(
            scale: _scale,
            child: SvgPicture.asset(
              'assets/icons/loading_waiting.svg',
              width: widget.size,
              height: widget.size,
              colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
            ),
          ),
          if (widget.label != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              widget.label!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
