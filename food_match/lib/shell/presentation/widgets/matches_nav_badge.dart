import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_extensions.dart';

class MatchesNavBadge extends StatefulWidget {
  const MatchesNavBadge({
    required this.count,
    required this.mode,
    required this.sessionId,
    required this.animation,
    required this.animationEventKey,
    super.key,
  });

  final int count;
  final String mode;
  final String? sessionId;
  final Animation<double> animation;
  final String? animationEventKey;

  @override
  State<MatchesNavBadge> createState() => _MatchesNavBadgeState();
}

class _MatchesNavBadgeState extends State<MatchesNavBadge> {
  bool? _lastAnimationActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.fmColors;
    if (kDebugMode) {
      debugPrint(
        '[BottomNavBadgeRender] tab=matches visible=${widget.count > 0} '
        'count=${widget.count} currentMode=${widget.mode} '
        'sessionId=${widget.sessionId ?? 'none'}',
      );
    }
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            top: 1,
            right: -1,
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (BuildContext context, Widget? child) {
                final double value = widget.animation.value;
                final bool active = value > 0 && value < 1;
                if (kDebugMode && active != _lastAnimationActive) {
                  _lastAnimationActive = active;
                  debugPrint(
                    '[BottomNavBadgeAnimRender] active=$active '
                    'eventKey=${widget.animationEventKey ?? 'none'}',
                  );
                }
                final double opacity = value <= 0.2
                    ? value / 0.2
                    : (1 - value) / 0.8;
                final double dy = value <= 0.2
                    ? 16 * (1 - (value / 0.2))
                    : -28 * ((value - 0.2) / 0.8);
                final double scale = value <= 0.2
                    ? 0.75 + (0.3 * (value / 0.2))
                    : 1.05 - (0.1 * ((value - 0.2) / 0.8));
                return Opacity(
                  key: const Key('matches-nav-plus-one'),
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(scale: scale, child: child),
                  ),
                );
              },
              child: SvgPicture.asset(
                'assets/icons/plus_one_badge.svg',
                width: 20,
                height: 10,
              ),
            ),
          ),
          if (widget.count > 0)
            Positioned(
              key: const Key('matches-nav-count-badge'),
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.badgeBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.bottomNavBackground,
                    width: 1.5,
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  widget.count > 99 ? '99+' : widget.count.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.badgeText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
