import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/app_pending_overlay.dart';
import 'core/utils/logger.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/couple/logic/couple_provider.dart';
import 'features/onboarding/data/onboarding_storage.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/startup/presentation/screens/food_match_splash_screen.dart';

class FoodMatchApp extends StatefulWidget {
  const FoodMatchApp({super.key});

  @override
  State<FoodMatchApp> createState() => _FoodMatchAppState();
}

class _FoodMatchAppState extends State<FoodMatchApp>
    with WidgetsBindingObserver {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 3000);

  late final GoRouter _router;
  final OnboardingStorage _onboardingStorage = OnboardingStorage();
  bool _isStartupComplete = false;
  bool _hasLoadedOnboardingState = false;
  bool _hasCompletedOnboarding = false;
  bool _isCompletingOnboarding = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final authProvider = context.read<AuthProvider>();
    _router = AppRouter(authProvider: authProvider).router;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapApp();
    });
  }

  Future<void> _bootstrapApp() async {
    final DateTime startedAt = DateTime.now();
    try {
      bool hasCompletedOnboarding = false;
      try {
        hasCompletedOnboarding = await _onboardingStorage.isCompleted();
      } catch (_) {
        // A storage read failure must not bypass first-install onboarding.
      }
      if (mounted) {
        _hasCompletedOnboarding = hasCompletedOnboarding;
        _hasLoadedOnboardingState = true;
      }

      final auth = context.read<AuthProvider>();
      await auth.loadUser();
      AppLogger.info(
        '[Startup] authResolved user=${auth.currentUser?.id ?? 'none'}',
      );
      if (!auth.isAuthenticated) {
        AppLogger.info('[Startup] outcome=login reason=not_authenticated');
      }
      if (auth.isAuthenticated && mounted) {
        final CoupleProvider coupleProvider = context.read<CoupleProvider>();
        await coupleProvider.loadCouple();
        coupleProvider.startInvitationPolling(reason: 'app_boot');
      }
    } finally {
      final Duration elapsed = DateTime.now().difference(startedAt);
      final Duration remaining = _minimumSplashDuration - elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (mounted) setState(() => _isStartupComplete = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final AuthProvider auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        auth.loadUser();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FoodMatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<ThemeController>().themeMode,
      routerConfig: _router,
      builder: (BuildContext context, Widget? child) {
        final Widget routerContent = child ?? const SizedBox.shrink();

        return FoodMatchStartupGate(
          isStartupComplete: _isStartupComplete,
          child: _OnboardingGate(
            hasLoadedOnboardingState: _hasLoadedOnboardingState,
            hasCompletedOnboarding: _hasCompletedOnboarding,
            onFinished: _completeOnboarding,
            child: AppPendingOverlay(child: routerContent),
          ),
        );
      },
    );
  }

  Future<void> _completeOnboarding() async {
    if (_isCompletingOnboarding) return;
    _isCompletingOnboarding = true;

    try {
      await _onboardingStorage.markCompleted();
      if (!mounted) return;

      final AuthProvider auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) {
        _router.go('/register');
      }

      setState(() => _hasCompletedOnboarding = true);
    } catch (_) {
      _isCompletingOnboarding = false;
      return;
    }
  }
}

class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate({
    required this.hasLoadedOnboardingState,
    required this.hasCompletedOnboarding,
    required this.onFinished,
    required this.child,
  });

  final bool hasLoadedOnboardingState;
  final bool hasCompletedOnboarding;
  final VoidCallback onFinished;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool showOnboarding =
        hasLoadedOnboardingState && !hasCompletedOnboarding;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeOutCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
      child: showOnboarding
          ? FoodMatchOnboardingScreen(
              key: const ValueKey<String>('onboarding'),
              onFinished: onFinished,
            )
          : KeyedSubtree(
              key: const ValueKey<String>('resolved-route'),
              child: child,
            ),
    );
  }
}
