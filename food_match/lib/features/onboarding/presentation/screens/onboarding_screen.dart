import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../widgets/onboarding_progress_button.dart';

class FoodMatchOnboardingScreen extends StatefulWidget {
  const FoodMatchOnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<FoodMatchOnboardingScreen> createState() =>
      _FoodMatchOnboardingScreenState();
}

class _FoodMatchOnboardingScreenState extends State<FoodMatchOnboardingScreen> {
  static const Duration _pageDuration = Duration(milliseconds: 480);
  static const Curve _pageCurve = Curves.easeOutCubic;

  final PageController _pageController = PageController();
  int _pageIndex = 0;
  bool _isAdvancing = false;

  static const List<_OnboardingPageData> _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      title: 'Can’t decide?',
      description:
          'After a long day, it’s not always easy to decide what to cook or order. FoodMatch helps you find the perfect meal in just a few swipes.',
      heroAsset: 'assets/onboarding/onboarding_hero_decide.png',
    ),
    _OnboardingPageData(
      title: 'Swipe Dishes',
      description:
          'Browse our dishes with a swipe, or add your own. Use FoodMatch alone or together to decide what’s for today.',
      heroAsset: 'assets/onboarding/onboarding_hero_swipe.png',
    ),
    _OnboardingPageData(
      title: 'Get a Match',
      description:
          'When you match, open the recipe, check the ingredients, and follow the step-by-step instructions to start cooking.',
      heroAsset: 'assets/onboarding/onboarding_hero_match.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handlePrimaryAction() async {
    if (_isAdvancing) return;
    if (_pageIndex == _pages.length - 1) {
      widget.onFinished();
      return;
    }

    setState(() => _isAdvancing = true);
    final int nextPage = _pageIndex + 1;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await _pageController.animateToPage(
      nextPage,
      duration: _pageDuration,
      curve: _pageCurve,
    );
    if (mounted) setState(() => _isAdvancing = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final _OnboardingPalette palette = _OnboardingPalette.fromBrightness(isDark);
    final String blobAsset = isDark
        ? 'assets/animations/onboarding_blob_dark.json'
        : 'assets/animations/onboarding_blob_light.json';

    return Material(
      color: palette.background,
      child: DefaultTextStyle(
        style: GoogleFonts.nunito(
          color: palette.description,
          decoration: TextDecoration.none,
        ),
        child: SafeArea(
          child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double contentWidth = constraints.maxWidth.clamp(0.0, 440.0).toDouble();
            final double textWidth = constraints.maxWidth < 700 ? 360.0 : 440.0;
            final double heroSize = constraints.maxWidth < 700 ? 330.0 : 440.0;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (int index) {
                            setState(() => _pageIndex = index);
                          },
                          itemCount: _pages.length,
                          itemBuilder: (BuildContext context, int index) {
                            return _OnboardingPage(
                              key: ValueKey<String>(_pages[index].title),
                              data: _pages[index],
                              blobAsset: blobAsset,
                              palette: palette,
                              heroSize: heroSize,
                              textWidth: textWidth,
                              pageIndex: index,
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 26, top: 18),
                        child: Semantics(
                          label: _pageIndex == _pages.length - 1
                              ? 'Continue to FoodMatch'
                              : 'Next onboarding screen',
                          value: 'Step ${_pageIndex + 1} of ${_pages.length}',
                          button: true,
                          child: OnboardingProgressButton(
                            progress: (_pageIndex + 1) / _pages.length,
                            semanticProgress:
                                'Step ${_pageIndex + 1} of ${_pages.length}',
                            onPressed: _handlePrimaryAction,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    super.key,
    required this.data,
    required this.blobAsset,
    required this.palette,
    required this.heroSize,
    required this.textWidth,
    required this.pageIndex,
  });

  final _OnboardingPageData data;
  final String blobAsset;
  final _OnboardingPalette palette;
  final double heroSize;
  final double textWidth;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).vertical -
              116,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 18),
            _StaggeredAppear(
              delay: Duration.zero,
              child: _HeroBlobStack(
                heroAsset: data.heroAsset,
                blobAsset: blobAsset,
                palette: palette,
                size: heroSize,
              ),
            ),
            const SizedBox(height: 28),
            _StaggeredAppear(
              delay: const Duration(milliseconds: 80),
              child: Semantics(
                header: true,
                child: Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    color: palette.title,
                    fontSize: 30,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _StaggeredAppear(
              delay: const Duration(milliseconds: 140),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textWidth),
                child: Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    color: palette.description,
                    fontSize: 15,
                    height: 1.36,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _HeroBlobStack extends StatelessWidget {
  const _HeroBlobStack({
    required this.heroAsset,
    required this.blobAsset,
    required this.palette,
    required this.size,
  });

  final String heroAsset;
  final String blobAsset;
  final _OnboardingPalette palette;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double effectiveSize = size.clamp(260.0, 440.0).toDouble();
    return SizedBox.square(
      dimension: effectiveSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox.square(
            dimension: effectiveSize * 0.96,
            child: Lottie.asset(
              blobAsset,
              repeat: true,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _BlobFallback(color: palette.blob),
            ),
          ),
          Image.asset(
            heroAsset,
            width: effectiveSize * 0.78,
            height: effectiveSize * 0.78,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _HeroFallback(color: palette.heroFallback),
          ),
        ],
      ),
    );
  }
}

class _StaggeredAppear extends StatefulWidget {
  const _StaggeredAppear({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredAppear> createState() => _StaggeredAppearState();
}

class _StaggeredAppearState extends State<_StaggeredAppear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final CurvedAnimation curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _offset = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(curved);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

class _BlobFallback extends StatelessWidget {
  const _BlobFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BlobFallbackPainter(color));
  }
}

class _BlobFallbackPainter extends CustomPainter {
  const _BlobFallbackPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.05)
      ..cubicTo(size.width * 0.84, 0, size.width, size.height * 0.24,
          size.width * 0.91, size.height * 0.55)
      ..cubicTo(size.width * 0.82, size.height * 0.88, size.width * 0.48,
          size.height, size.width * 0.20, size.height * 0.82)
      ..cubicTo(-size.width * 0.05, size.height * 0.66, size.width * 0.02,
          size.height * 0.26, size.width * 0.50, size.height * 0.05)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BlobFallbackPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const Icon(Icons.restaurant_rounded, size: 88, color: Colors.white),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.heroAsset,
  });

  final String title;
  final String description;
  final String heroAsset;
}

class _OnboardingPalette {
  const _OnboardingPalette({
    required this.background,
    required this.title,
    required this.description,
    required this.blob,
    required this.heroFallback,
  });

  final Color background;
  final Color title;
  final Color description;
  final Color blob;
  final Color heroFallback;

  factory _OnboardingPalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _OnboardingPalette(
        background: Color(0xFF2A2421),
        title: Color(0xFFFFF9F5),
        description: Color(0xFFC9B8B0),
        blob: Color(0xFF4C3830),
        heroFallback: Color(0xFFDE704B),
      );
    }
    return const _OnboardingPalette(
      background: Color(0xFFFFF9F7),
      title: Color(0xFF2D2521),
      description: Color(0xFF7B6F69),
      blob: Color(0xFFFFE2D6),
      heroFallback: Color(0xFFFF8A5C),
    );
  }
}
