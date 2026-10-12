import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_match/data/services/api_service.dart';
import 'package:food_match/features/premium/data/premium_repository.dart';
import 'package:food_match/features/premium/domain/effective_entitlements.dart';
import 'package:food_match/features/premium/logic/premium_provider.dart';

void main() {
  for (final status in [503, 200]) {
    test(
      'HTTP $status through the real repository preserves resolution and ad rules',
      () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/entitlements/me');
          return http.Response(
            status == 503
                ? '{"code":"ENTITLEMENT_RESOLUTION_UNAVAILABLE","message":"Entitlements unavailable"}'
                : '{"tier":"free","isPremium":false,"features":{},"limits":{"customDishes":3}}',
            status,
            headers: {'content-type': 'application/json'},
          );
        });
        final provider = PremiumProvider(
          repository: ApiPremiumRepository(
            ApiService(
              client: client,
              accessTokenProvider: () => 'test-access-token',
            ),
          ),
        );
        addTearDown(provider.dispose);
        addTearDown(client.close);
        final resolved = Completer<void>();
        provider.addListener(() {
          if (provider.resolutionState == EntitlementResolutionState.loading) {
            expect(provider.shouldRequestAds, isFalse);
          }
          if (provider.resolutionState == EntitlementResolutionState.ready ||
              provider.resolutionState == EntitlementResolutionState.error) {
            if (!resolved.isCompleted) resolved.complete();
          }
        });
        expect(provider.shouldRequestAds, isFalse);
        provider.setAuthenticatedUser('user', isAuthenticated: true);
        await resolved.future;
        expect(
          provider.resolutionState,
          status == 503
              ? EntitlementResolutionState.error
              : EntitlementResolutionState.ready,
        );
        expect(provider.shouldRequestAds, status == 200);
        expect(provider.isPremium, isFalse);
        expect(provider.canUse(PremiumFeature.advancedFilters), isFalse);
        expect(provider.canUse(PremiumFeature.sharedShoppingList), isFalse);
      },
    );
  }
}
