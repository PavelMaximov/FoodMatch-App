import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class FoodMatchStartupGate extends StatefulWidget {
  const FoodMatchStartupGate({
    super.key,
    required this.isStartupComplete,
    required this.child,
  });

  final bool isStartupComplete;
  final Widget child;

  @override
  State<FoodMatchStartupGate> createState() => _FoodMatchStartupGateState();
}

class _FoodMatchStartupGateState extends State<FoodMatchStartupGate> {
  static const Duration _progressTick = Duration(milliseconds: 90);
  static const Duration _completionPause = Duration(milliseconds: 240);

  Timer? _progressTimer;
  double _progress = 0.08;
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[StartupGate] init');
    _startProgress();
    if (widget.isStartupComplete) _completeStartup();
  }

  @override
  void didUpdateWidget(covariant FoodMatchStartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isStartupComplete && widget.isStartupComplete) {
      _completeStartup();
    }
  }

  void _startProgress() {
    _progressTimer = Timer.periodic(_progressTick, (_) {
      if (!mounted || _progress >= 0.88 || widget.isStartupComplete) return;
      setState(() {
        _progress = (_progress + 0.024).clamp(0, 0.88).toDouble();
      });
    });
  }

  Future<void> _completeStartup() async {
    _progressTimer?.cancel();
    if (mounted) setState(() => _progress = 1);
    await Future<void>.delayed(_completionPause);
    if (mounted) {
      debugPrint('[StartupGate] splash complete');
      setState(() => _showApp = true);
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _showApp
          ? KeyedSubtree(
              key: const ValueKey<String>('app'),
              child: widget.child,
            )
          : FoodMatchSplashScreen(
              key: const ValueKey<String>('splash'),
              progress: _progress,
            ),
    );
  }
}

class FoodMatchSplashScreen extends StatelessWidget {
  const FoodMatchSplashScreen({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background = isDark
        ? const Color(0xFF2A2421)
        : const Color(0xFFFFF9F7);
    final Color tagline = isDark
        ? const Color(0xFFB9A59D)
        : const Color(0xFF8C8C8C);
    final Color track = isDark
        ? const Color(0xFF3B322E)
        : const Color(0xFFF3E8E3);
    final Color trackBorder = isDark
        ? const Color(0xFF5B4A43)
        : const Color(0xFFE8D9D2);
    final String logoAsset = isDark
        ? 'assets/animations/splash_logo_dark.json'
        : 'assets/animations/splash_logo_light.json';

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isLarge = constraints.maxWidth >= 700;
            final double logoWidth = (constraints.maxWidth * 0.76).clamp(
              260.0,
              620.0,
            );
            final double progressWidth = (constraints.maxWidth * 0.57).clamp(
              220.0,
              520.0,
            );
            final double taglineSpacing = isLarge ? 26 : 20;
            final double logoBottomInset = (logoWidth / 2.7) * 0.30;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          width: logoWidth,
                          child: AspectRatio(
                            aspectRatio: 2.7,
                            child: Lottie.asset(
                              logoAsset,
                              fit: BoxFit.contain,
                              repeat: false,
                              errorBuilder: (_, __, ___) => _FallbackLogo(
                                isDark: isDark,
                                isLarge: isLarge,
                              ),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(
                            0,
                            -(logoBottomInset - taglineSpacing),
                          ),
                          child: Text(
                            'Swipe. Match. Dine',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              color: tagline,
                              fontSize: isLarge ? 28 : 21,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              decoration: TextDecoration.none,
                              decorationColor: Colors.transparent,
                              decorationThickness: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: isLarge ? 110 : 88,
                  child: Center(
                    child: Semantics(
                      label: 'Starting FoodMatch',
                      value: '${(progress * 100).round()} percent',
                      child: _SplashProgressBar(
                        width: progressWidth,
                        progress: progress,
                        track: track,
                        border: trackBorder,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SplashProgressBar extends StatelessWidget {
  const _SplashProgressBar({
    required this.width,
    required this.progress,
    required this.track,
    required this.border,
  });

  final double width;
  final double progress;
  final Color track;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            widthFactor: progress.clamp(0, 1).toDouble(),
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFFFFC447), Color(0xFFFF7043)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.isDark, required this.isLarge});

  final bool isDark;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'FoodMatch',
        style: GoogleFonts.fredoka(
          color: isDark ? const Color(0xFFFFF4EE) : const Color(0xFF342823),
          fontSize: isLarge ? 72 : 52,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
