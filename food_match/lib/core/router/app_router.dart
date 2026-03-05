import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/couple/presentation/screens/connect_couple_screen.dart';
import '../../features/dishes/presentation/screens/add_dish_screen.dart';
import '../../features/dishes/presentation/screens/recipe_detail_screen.dart';
import '../../features/matches/presentation/screens/match_overlay_screen.dart';
import '../../features/matches/presentation/screens/matches_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/swipes/presentation/screens/swipes_screen.dart';
import '../../shell/presentation/screens/main_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/connect-couple',
        builder: (BuildContext context, GoRouterState state) =>
            const ConnectCoupleScreen(),
      ),
      GoRoute(
        path: '/recipe/:dishId',
        builder: (BuildContext context, GoRouterState state) => RecipeDetailScreen(
          dishId: state.pathParameters['dishId'] ?? 'unknown',
        ),
      ),
      GoRoute(
        path: '/match-overlay',
        builder: (BuildContext context, GoRouterState state) =>
            const MatchOverlayScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
                StatefulNavigationShell navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/swipes',
                builder: (BuildContext context, GoRouterState state) =>
                    const SwipesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/matches',
                builder: (BuildContext context, GoRouterState state) =>
                    const MatchesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/add-dish',
                builder: (BuildContext context, GoRouterState state) =>
                    const AddDishScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
