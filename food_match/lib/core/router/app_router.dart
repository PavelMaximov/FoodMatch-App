import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/dish.dart';
import '../../features/auth/logic/auth_provider.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/couple/presentation/widgets/connect_session_sheet.dart';
import '../../features/dishes/presentation/screens/add_dish_screen.dart';
import '../../features/dishes/presentation/screens/recipe_detail_screen.dart';
import '../../features/matches/presentation/screens/match_overlay_screen.dart';
import '../../features/matches/presentation/screens/matches_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/recipes/presentation/screens/recipes_screen.dart';
import '../../features/swipes/presentation/screens/swipes_screen.dart';
import '../../shell/presentation/screens/main_shell.dart';

class AppRouter {
  AppRouter({required AuthProvider authProvider})
      : router = GoRouter(
          initialLocation: '/login',
          refreshListenable: authProvider,
          redirect: (BuildContext context, GoRouterState state) {
            final bool isLoggedIn = authProvider.isAuthenticated;
            final bool isAuthRoute = state.matchedLocation == '/login' ||
                state.matchedLocation == '/register' ||
                state.matchedLocation == '/forgot-password';

            if (!isLoggedIn && !isAuthRoute) {
              return '/login';
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
            GoRoute(
              path: '/connect-couple',
              builder: (_, __) => const Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(child: ConnectSessionSheet()),
              ),
            ),
            GoRoute(
              path: '/recipe-detail/:dishId',
              builder: (BuildContext context, GoRouterState state) => RecipeDetailScreen(
                dishId: state.pathParameters['dishId'] ?? 'unknown',
                dish: state.extra is Dish ? state.extra! as Dish : null,
              ),
            ),
            GoRoute(
              path: '/match-overlay',
              builder: (BuildContext context, GoRouterState state) => MatchOverlayScreen(
                dish: state.extra is Dish ? state.extra! as Dish : null,
              ),
            ),
            StatefulShellRoute.indexedStack(
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
                    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
                  ],
                ),
              ],
            ),
          ],
        );

  final GoRouter router;
}
