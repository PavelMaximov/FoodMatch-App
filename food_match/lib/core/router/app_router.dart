import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../animations/app_motion.dart';
import 'app_route_transitions.dart';
import '../../data/models/dish.dart';
import '../../data/models/match_history.dart';
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
import '../../features/profile/presentation/screens/profile_detail_screens.dart';
import '../../features/recipes/presentation/screens/recipes_screen.dart';
import '../../features/shopping_list/presentation/screens/shopping_list_screen.dart';
import '../../features/swipes/presentation/screens/swipes_screen.dart';
import '../../shared/widgets/root_tab_skeleton.dart';
import '../../shell/presentation/screens/main_shell.dart';

class AppRouter {
  AppRouter({
    required AuthProvider authProvider,
  }) : router = GoRouter(
          initialLocation: '/login',
          refreshListenable: authProvider,
          redirect: (BuildContext context, GoRouterState state) {
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
                  source: state.uri.queryParameters['source'],
                ),
              ),
            ),
            GoRoute(
              path: '/shopping-list',
              name: 'shoppingList',
              pageBuilder: (BuildContext context, GoRouterState state) =>
                  CustomTransitionPage<void>(
                key: state.pageKey,
                transitionDuration: const Duration(milliseconds: 380),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                child: const ShoppingListScreen(),
                transitionsBuilder: slideFromRightFadeTransition,
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
                  RootTabBranchStack(
                currentIndex: navigationShell.currentIndex,
                children: children,
              ),
              builder: (
                BuildContext context,
                GoRouterState state,
                StatefulNavigationShell navigationShell,
              ) =>
                  MainShell(
                    key: ValueKey<String>(authProvider.currentUser?.id ?? 'anonymous'),
                    navigationShell: navigationShell,
                  ),
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
                        GoRoute(
                          path: 'edit',
                          builder: (_, __) => const EditProfileScreen(),
                        ),
                        GoRoute(
                          path: 'edit-profile',
                          redirect: (_, __) => '/profile/edit',
                        ),
                        GoRoute(path: 'settings', builder: (_, __) => const ProfileSettingsScreen()),
                        GoRoute(
                          path: 'match-history',
                          builder: (_, __) => const MatchHistoryScreen(),
                          routes: <RouteBase>[
                            GoRoute(
                              path: 'session/:sessionId',
                              builder: (_, GoRouterState state) =>
                                  MatchHistorySessionScreen(
                                    sessionId:
                                        state.pathParameters['sessionId']!,
                                    initialSession:
                                        state.extra is MatchHistorySession
                                        ? state.extra! as MatchHistorySession
                                        : null,
                                  ),
                            ),
                          ],
                        ),
                        GoRoute(path: 'about', builder: (_, __) => const AboutFoodMatchScreen()),
                        GoRoute(path: 'help', builder: (_, __) => const HelpScreen()),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

  final GoRouter router;
}

class RootTabBranchStack extends StatefulWidget {
  /// Keeps branch navigators alive while switching the visible branch without
  /// producing intermediate page-change events for non-adjacent tab taps.
  const RootTabBranchStack({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<RootTabBranchStack> createState() => _RootTabBranchStackState();
}

class _RootTabBranchStackState extends State<RootTabBranchStack> {
  late final Set<int> _visitedBranches;
  late List<Widget> _tabPages;

  @override
  void initState() {
    super.initState();
    _visitedBranches = <int>{widget.currentIndex};
    _tabPages = _buildTabPages(widget.children);
  }

  @override
  void didUpdateWidget(covariant RootTabBranchStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children != widget.children) {
      _tabPages = _buildTabPages(widget.children);
    }
    final int currentIndex = widget.currentIndex;
    if (_visitedBranches.add(currentIndex)) {
      _tabPages = _buildTabPages(widget.children);
    }
  }

  List<Widget> _buildTabPages(List<Widget> children) {
    return List<Widget>.generate(children.length, (int index) {
      return KeyedSubtree(
        key: PageStorageKey<String>('root-tab-$index'),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RootTabSkeleton(type: _skeletonTypeFor(index)),
            RepaintBoundary(child: children[index]),
            if (!_visitedBranches.contains(index))
              RootTabSkeleton(type: _skeletonTypeFor(index)),
          ],
        ),
      );
    });
  }

  RootTabSkeletonType _skeletonTypeFor(int index) {
    switch (index) {
      case 0:
        return RootTabSkeletonType.recipes;
      case 1:
        return RootTabSkeletonType.matches;
      case 2:
        return RootTabSkeletonType.swipes;
      case 3:
        return RootTabSkeletonType.addDish;
      case 4:
        return RootTabSkeletonType.profile;
      default:
        return RootTabSkeletonType.recipes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      key: const Key('root-tab-stack'),
      index: widget.currentIndex,
      sizing: StackFit.expand,
      children: _tabPages,
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
