import 'dart:async';
import 'package:food_match/features/swipes/presentation/screens/swipes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:food_match/core/router/app_router.dart';
import 'package:food_match/features/auth/logic/auth_provider.dart';
import 'package:food_match/features/premium/data/premium_repository.dart';
import 'package:food_match/features/premium/domain/effective_entitlements.dart';
import 'package:food_match/features/premium/domain/premium_entry_point.dart';
import 'package:food_match/features/premium/logic/premium_provider.dart';
import 'package:food_match/features/premium/presentation/premium_screen.dart';
import 'package:food_match/features/profile/presentation/screens/profile_detail_screens.dart';
import 'package:food_match/features/shopping_list/presentation/screens/shopping_list_screen.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthenticated => true;
  @override
  bool get needsEmailVerification => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements PremiumRepository {
  _Repository(this.value);
  final EffectiveEntitlements value;
  @override
  Future<EffectiveEntitlements> fetchMyEntitlements() async => value;
}

Iterable<GoRoute> _routes(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) {
      yield route;
      yield* _routes(route.routes);
    }
    if (route is StatefulShellRoute) {
      for (final branch in route.branches) {
        yield* _routes(branch.routes);
      }
    }
    if (route is ShellRoute) yield* _routes(route.routes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'recipe to Premium or shopping keeps one shell and unique page keys',
    () {
      final auth = _Auth();
      final router = AppRouter(authProvider: auth).router;
      addTearDown(router.dispose);
      addTearDown(auth.dispose);
      for (final tab in ['/recipes', '/swipes', '/profile']) {
        final base = router.configuration.findMatch(Uri.parse(tab));
        final recipe = base.push(
          ImperativeRouteMatch(
            pageKey: const ValueKey('recipe-push'),
            matches: router.configuration.findMatch(
              Uri.parse('/recipe-detail/dish'),
            ),
            completer: Completer<Object?>(),
          ),
        );
        for (final destination in ['/profile/premium', '/shopping-list']) {
          final result = recipe.push(
            ImperativeRouteMatch(
              pageKey: const ValueKey('destination-push'),
              matches: router.configuration.findMatch(Uri.parse(destination)),
              completer: Completer<Object?>(),
            ),
          );
          final keys = result.matches.map((match) => match.pageKey).toList();
          expect(
            keys.toSet().length,
            keys.length,
            reason: '$tab -> recipe -> $destination',
          );
          expect(result.matches.whereType<ShellRouteMatch>(), hasLength(1));
          expect(result.remove(result.matches.last).matches, recipe.matches);
        }
      }
    },
  );

  testWidgets('invitation reuses Swipes setup with the supplied code', (
    tester,
  ) async {
    final auth = _Auth();
    final router = AppRouter(authProvider: auth).router;
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    final routes = _routes(router.configuration.routes).toList();
    final invitation = routes.firstWhere(
      (route) => route.path == '/connect-couple',
    );
    final swipes = routes.firstWhere((route) => route.path == '/swipes');
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    GoRouterState state(String path, Uri uri) => GoRouterState(
      router.configuration,
      uri: uri,
      matchedLocation: path,
      fullPath: path,
      pathParameters: const {},
      pageKey: const ValueKey('invite'),
    );
    for (final code in ['ABC123', 'XY9876']) {
      final destination = await invitation.redirect!(
        context,
        state('/connect-couple', Uri.parse('/connect-couple?code=$code')),
      );
      expect(destination, '/swipes?inviteCode=$code');
      final screen = swipes.builder!(
        context,
        state('/swipes', Uri.parse(destination!)),
      );
      expect(screen, isA<SwipesScreen>());
      expect((screen as SwipesScreen).initialInvitationCode, code);
    }
    expect(invitation.builder, isNull, reason: 'No standalone invitation form');
  });

  for (final access in ['free', 'premium', 'pair', 'pair-without-session']) {
    testWidgets(
      '$access selects production Shopping List and history destinations',
      (tester) async {
        final value = access == 'free'
            ? EffectiveEntitlements.free
            : EffectiveEntitlements(
                tier: access == 'premium'
                    ? SubscriptionTier.premium
                    : SubscriptionTier.free,
                status: SubscriptionStatus.active,
                features: access == 'premium'
                    ? {
                        PremiumFeature.shoppingList,
                        PremiumFeature.sessionHistory,
                      }
                    : {PremiumFeature.sharedShoppingList},
                customDishLimit: access == 'premium' ? null : 3,
              );
        final premium = PremiumProvider(repository: _Repository(value));
        premium.setAuthenticatedUser('user', isAuthenticated: true);
        if (access == 'pair') {
          premium.handlePairContext('active-pair');
        }
        await tester.pump();
        final auth = _Auth();
        final router = AppRouter(authProvider: auth).router;
        addTearDown(router.dispose);
        addTearDown(auth.dispose);
        addTearDown(premium.dispose);
        final routes = _routes(router.configuration.routes).toList();
        final shopping = routes.firstWhere((r) => r.path == '/shopping-list');
        final history = routes.firstWhere((r) => r.path == 'match-history');
        final detail = routes.firstWhere((r) => r.path == 'session/:sessionId');
        GoRouterState state(GoRoute route) => GoRouterState(
          router.configuration,
          uri: Uri.parse('/test'),
          matchedLocation: '/test',
          fullPath: route.path,
          pathParameters: const {'sessionId': 'session'},
          pageKey: const ValueKey('test'),
        );
        late Widget shoppingDestination, historyDestination, detailDestination;
        await tester.pumpWidget(
          ChangeNotifierProvider<PremiumProvider>.value(
            value: premium,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  shoppingDestination =
                      (shopping.pageBuilder!(context, state(shopping))
                              as CustomTransitionPage<void>)
                          .child;
                  historyDestination = history.builder!(
                    context,
                    state(history),
                  );
                  detailDestination = detail.builder!(context, state(detail));
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        if (access == 'free' || access == 'pair-without-session') {
          expect(shoppingDestination, isA<PremiumScreen>());
          expect(
            (shoppingDestination as PremiumScreen).entryPoint,
            PremiumEntryPoint.shoppingList,
          );
        } else {
          expect(shoppingDestination, isA<ShoppingListScreen>());
        }
        if (access == 'premium') {
          expect(historyDestination, isA<MatchHistoryScreen>());
          expect(detailDestination, isA<MatchHistorySessionScreen>());
        } else {
          expect(
            (historyDestination as PremiumScreen).entryPoint,
            PremiumEntryPoint.sessionHistory,
          );
          expect(
            (detailDestination as PremiumScreen).entryPoint,
            PremiumEntryPoint.sessionHistory,
          );
        }
      },
    );
  }
}
