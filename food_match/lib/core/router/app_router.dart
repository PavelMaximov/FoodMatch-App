import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../animations/app_motion.dart';
import '../../data/models/dish.dart';
import '../../features/auth/logic/auth_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/couple/presentation/widgets/connect_session_sheet.dart';
import '../../features/dishes/presentation/screens/add_dish_screen.dart';
import '../../features/dishes/presentation/screens/recipe_detail_screen.dart';
import '../../features/matches/presentation/screens/match_overlay_screen.dart';
import '../../features/matches/presentation/screens/matches_screen.dart';
import '../../features/favorites/presentation/screens/favorites_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/recipes/presentation/screens/recipes_screen.dart';
import '../../features/swipes/presentation/screens/swipes_screen.dart';
import '../../shell/presentation/screens/main_shell.dart';

class AppRouter {
  AppRouter({
    required AuthProvider authProvider,
    required ValueChanged<bool> onSensitiveRouteChanged,
  }) : router = GoRouter(
          initialLocation: '/login',
          refreshListenable: authProvider,
          redirect: (BuildContext context, GoRouterState state) {
            onSensitiveRouteChanged(_isSensitiveLocation(state.matchedLocation));
            final bool isLoggedIn = authProvider.isAuthenticated;
            final bool isAuthRoute = state.matchedLocation == '/login' ||
                state.matchedLocation == '/register' ||
                state.matchedLocation == '/forgot-password';
            final bool isVerifyRoute = state.matchedLocation == '/verify-email';

            if (!isLoggedIn && !isAuthRoute) {
              return '/login';
            }
            if (isLoggedIn && authProvider.needsEmailVerification && !isVerifyRoute) {
              return '/verify-email';
            }
            if (isLoggedIn && !authProvider.needsEmailVerification && isVerifyRoute) {
              return '/swipes';
            }
            if (isLoggedIn && isAuthRoute) {
              return '/swipes';
            }
            return null;
          },
          routes: <RouteBase>[
            GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
            GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
            GoRoute(
              path: '/forgot-password',
              builder: (_, __) => const ForgotPasswordScreen(),
            ),
            GoRoute(path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
            GoRoute(
              path: '/connect-couple',
              builder: (_, __) => const Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(child: ConnectSessionSheet()),
              ),
            ),
            GoRoute(
              path: '/recipe-detail/:dishId',
              pageBuilder: (BuildContext context, GoRouterState state) => _bottomUpPage(
                context: context,
                state: state,
                child: RecipeDetailScreen(
                  dishId: state.pathParameters['dishId'] ?? 'unknown',
                  dish: state.extra is Dish ? state.extra! as Dish : null,
                ),
              ),
            ),
            GoRoute(
              path: '/match-overlay',
              pageBuilder: (BuildContext context, GoRouterState state) => _fadeScalePage(
                context: context,
                state: state,
                child: MatchOverlayScreen(
                  dish: state.extra is Dish ? state.extra! as Dish : null,
                ),
              ),
            ),
            StatefulShellRoute(
              navigatorContainerBuilder: (
                BuildContext context,
                StatefulNavigationShell navigationShell,
                List<Widget> children,
              ) =>
                  _PagedBranchNavigatorContainer(
                navigationShell: navigationShell,
                children: children,
              ),
              builder: (
                BuildContext context,
                GoRouterState state,
                StatefulNavigationShell navigationShell,
              ) =>
                  MainShell(navigationShell: navigationShell),
              branches: <StatefulShellBranch>[
                StatefulShellBranch(
                  routes: <RouteBase>[
                    GoRoute(path: '/recipes', builder: (_, __) => const RecipesScreen()),
                    GoRoute(
                      path: '/favorites',
                      pageBuilder: (BuildContext context, GoRouterState state) =>
                          _bottomUpPage(
                        context: context,
                        state: state,
                        child: const FavoritesScreen(),
                      ),
                    ),
                  ],
                ),
                StatefulShellBranch(
                  routes: <RouteBase>[
                    GoRoute(path: '/matches', builder: (_, __) => const MatchesScreen()),
                  ],
                ),
                StatefulShellBranch(
                  routes: <RouteBase>[
                    GoRoute(path: '/swipes', builder: (_, __) => const SwipesScreen()),
                  ],
                ),
                StatefulShellBranch(
                  routes: <RouteBase>[
                    GoRoute(path: '/add-dish', builder: (_, __) => const AddDishScreen()),
                  ],
                ),
                StatefulShellBranch(
                  routes: <RouteBase>[
                    GoRoute(
                      path: '/profile',
                      builder: (_, __) => const ProfileScreen(),
                      routes: <RouteBase>[
                        GoRoute(path: 'settings', builder: (_, __) => const ProfileSettingsScreen()),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

  final GoRouter router;

  static bool _isSensitiveLocation(String location) {
    return <String>{
      '/login',
      '/register',
      '/verify-email',
      '/connect-couple',
      '/profile',
    }.contains(location);
  }
}



class _PagedBranchNavigatorContainer extends StatefulWidget {
  const _PagedBranchNavigatorContainer({
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<_PagedBranchNavigatorContainer> createState() =>
      _PagedBranchNavigatorContainerState();
}

class _PagedBranchNavigatorContainerState
    extends State<_PagedBranchNavigatorContainer> {
  late final PageController _pageController;
  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.navigationShell.currentIndex,
      keepPage: true,
    );
  }

  @override
  void didUpdateWidget(covariant _PagedBranchNavigatorContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int currentIndex = widget.navigationShell.currentIndex;
    if (!_pageController.hasClients ||
        (_pageController.page?.round() ?? _pageController.initialPage) ==
            currentIndex) {
      return;
    }
    _animateToBranch(currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateToBranch(int index) async {
    if (!_pageController.hasClients) {
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: AppMotion.durationFor(context, AppMotion.tab),
      curve: AppMotion.curve,
    );
  }

  void _handlePageChanged(int index) {
    if (index == widget.navigationShell.currentIndex) {
      return;
    }
    widget.navigationShell.goBranch(index);
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      physics: const PageScrollPhysics(),
      onPageChanged: _handlePageChanged,
      children: widget.children,
    );
  }
}

CustomTransitionPage<void> _bottomUpPage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: AppMotion.durationFor(context, AppMotion.normal),
    reverseTransitionDuration: AppMotion.durationFor(context, AppMotion.normal),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<Offset> offset = Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: AppMotion.curve)).animate(animation);
      return SlideTransition(position: offset, child: child);
    },
  );
}

CustomTransitionPage<void> _fadeScalePage({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: AppMotion.durationFor(context, AppMotion.fast),
    reverseTransitionDuration: AppMotion.durationFor(context, AppMotion.fast),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.curve,
        reverseCurve: AppMotion.curve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
