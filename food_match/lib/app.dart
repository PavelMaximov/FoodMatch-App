import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/app_pending_overlay.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/couple/logic/couple_provider.dart';
import 'features/onboarding/presentation/screens/onboarding_screen.dart';
import 'features/startup/presentation/screens/food_match_splash_screen.dart';

const String kOnboardingCompletedStorageKey = 'foodmatch_onboarding_completed';

class FoodMatchApp extends StatefulWidget {
  const FoodMatchApp({super.key});

  @override
  State<FoodMatchApp> createState() => _FoodMatchAppState();
}

class _FoodMatchAppState extends State<FoodMatchApp>
    with WidgetsBindingObserver {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 3000);

  late final GoRouter _router;
  bool _isStartupComplete = false;
  bool _hasCompletedOnboarding = false;

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
      final auth = context.read<AuthProvider>();
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      _hasCompletedOnboarding =
          preferences.getBool(kOnboardingCompletedStorageKey) ?? false;
      await auth.loadUser();
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
            hasCompletedOnboarding: _hasCompletedOnboarding,
            onFinished: _completeOnboarding,
            child: AppPendingOverlay(child: routerContent),
          ),
        );
      },
    );
  }
  Future<void> _completeOnboarding() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(kOnboardingCompletedStorageKey, true);
    if (!mounted) return;
    setState(() => _hasCompletedOnboarding = true);
    context.go('/register');
  }
}

class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate({
    required this.hasCompletedOnboarding,
    required this.onFinished,
    required this.child,
  });

  final bool hasCompletedOnboarding;
  final Future<void> Function() onFinished;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();
    final bool showOnboarding =
        !authProvider.isAuthenticated && !hasCompletedOnboarding;

    if (!showOnboarding) return child;

    return FoodMatchOnboardingScreen(onFinished: onFinished);
  }
}
