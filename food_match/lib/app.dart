import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/app_pending_overlay.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/couple/logic/couple_provider.dart';
import 'features/startup/presentation/screens/food_match_splash_screen.dart';

class FoodMatchApp extends StatefulWidget {
  const FoodMatchApp({super.key});

  @override
  State<FoodMatchApp> createState() => _FoodMatchAppState();
}

class _FoodMatchAppState extends State<FoodMatchApp>
    with WidgetsBindingObserver {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 1000);

  late final GoRouter _router;
  bool _isStartupComplete = false;

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
      builder: (BuildContext context, Widget? child) => FoodMatchStartupGate(
        isStartupComplete: _isStartupComplete,
        child: AppPendingOverlay(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
