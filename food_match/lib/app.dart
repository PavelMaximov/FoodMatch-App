import 'package:shared_preferences/shared_preferences.dart';
import 'core/links/session_invitation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/locale_controller.dart';
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
import 'dart:async';
import 'package:app_links/app_links.dart';

class FoodMatchApp extends StatefulWidget {
  const FoodMatchApp({super.key});

  @override
  State<FoodMatchApp> createState() => _FoodMatchAppState();
}

class _FoodMatchAppState extends State<FoodMatchApp>
    with WidgetsBindingObserver {
  static const Duration _minimumSplashDuration = Duration(milliseconds: 3000);
  StreamSubscription<Uri>? _deepLinkSubscription;
  final AppLinks _appLinks = AppLinks();

  late final GoRouter _router;
  late final AuthProvider _auth;
  late final SessionInvitationInbox _invitations;
  bool _inviteDeliveryScheduled = false;
  final OnboardingStorage _onboardingStorage = OnboardingStorage();
  bool _isStartupComplete = false;
  bool _hasLoadedOnboardingState = false;
  bool _hasCompletedOnboarding = false;
  bool _isCompletingOnboarding = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _auth = context.read<AuthProvider>();
    _router = AppRouter(authProvider: _auth).router;
    _invitations = SessionInvitationInbox(
      read: () async => (await SharedPreferences.getInstance()).getString(
        'pending_session_invitation',
      ),
      write: (code) async {
        final prefs = await SharedPreferences.getInstance();
        final saved = code == null
            ? await prefs.remove('pending_session_invitation')
            : await prefs.setString('pending_session_invitation', code);
        if (!saved) throw StateError('Invitation storage unavailable');
      },
    );
    _auth.addListener(_scheduleInvitationDelivery);

    _initializeInvitationLinks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapApp();
    });
  }

  Future<void> _initializeInvitationLinks() async {
    try {
      try {
        await _invitations.restore();
      } catch (_) {
        AppLogger.info('[Invite] saved invitation unavailable');
      }
      if (!mounted) return;
      final links = _appLinks;
      bool receivedLiveInvitation = false;
      _deepLinkSubscription = links.uriLinkStream.listen((uri) {
        if (invitationCode(uri) != null) receivedLiveInvitation = true;
        _receiveInvitation(uri);
      }, onError: (Object _) => AppLogger.info('[Invite] link unavailable'));
      final initial = await links.getInitialLink();
      if (initial != null && mounted && !receivedLiveInvitation) {
        await _receiveInvitation(initial);
      }
      _scheduleInvitationDelivery();
    } catch (_) {
      AppLogger.info('[Invite] unable to restore invitation');
    }
  }

  Future<void> _receiveInvitation(Uri uri) async {
    try {
      await _invitations.receive(uri);
      _scheduleInvitationDelivery();
    } catch (_) {
      AppLogger.info('[Invite] unable to save invitation');
    }
  }

  bool get _canOpenInvitation =>
      mounted &&
      _isStartupComplete &&
      _hasLoadedOnboardingState &&
      _hasCompletedOnboarding &&
      _auth.isAuthenticated &&
      !_auth.needsEmailVerification;

  void _scheduleInvitationDelivery() {
    if (!mounted || _inviteDeliveryScheduled) return;
    _inviteDeliveryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _inviteDeliveryScheduled = false;
      if (!mounted) return;
      try {
        await _invitations.deliver(
          isReady: () => _canOpenInvitation,
          navigate: (code) => _router.go(
            Uri(
              path: '/connect-couple',
              queryParameters: {'code': code},
            ).toString(),
          ),
        );
      } catch (_) {
        AppLogger.info('[Invite] delivery deferred');
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
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

      if (!mounted) return;
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
      if (mounted) {
        setState(() => _isStartupComplete = true);
        _scheduleInvitationDelivery();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSubscription?.cancel();
    _auth.removeListener(_scheduleInvitationDelivery);
    _invitations.dispose();
    _router.dispose();
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
      locale: context.watch<LocaleController?>()?.locale,
      supportedLocales: LocaleController.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
      _scheduleInvitationDelivery();
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
