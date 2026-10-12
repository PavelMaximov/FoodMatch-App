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
  for (final access in ['free', 'premium', 'pair']) {
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
        if (access == 'free') {
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
