import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/security/api_security_config.dart';
import 'core/security/privacy_overlay.dart';
import 'core/security/screen_security_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/logic/auth_provider.dart';
import 'features/couple/logic/couple_provider.dart';

class FoodMatchApp extends StatefulWidget {
  const FoodMatchApp({super.key});

  @override
  State<FoodMatchApp> createState() => _FoodMatchAppState();
}

class _FoodMatchAppState extends State<FoodMatchApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  bool _showPrivacyOverlay = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    final authProvider = context.read<AuthProvider>();
    _router = AppRouter(
      authProvider: authProvider,
      onSensitiveRouteChanged: _handleSensitiveRouteChanged,
    ).router;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.loadUser();
      if (auth.isAuthenticated && mounted) {
        await context.read<CoupleProvider>().loadCouple();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ScreenSecurityService.instance.setSecureScreenEnabled(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool shouldHide = ClientProtectionConfig.enablePrivacyOverlay &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached);
    if (shouldHide != _showPrivacyOverlay && mounted) {
      setState(() => _showPrivacyOverlay = shouldHide);
    }

    if (state == AppLifecycleState.resumed && mounted) {
      final AuthProvider auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        auth.loadUser();
      }
    }
  }

  void _handleSensitiveRouteChanged(bool isSensitive) {
    ScreenSecurityService.instance.setSecureScreenEnabled(
      ClientProtectionConfig.enableScreenSecurity && isSensitive,
    );
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
        return Stack(
          alignment: Alignment.topLeft,
          children: <Widget>[
            child ?? const SizedBox.shrink(),
            if (_showPrivacyOverlay) const PrivacyOverlay(),
          ],
        );
      },
    );
  }
}
