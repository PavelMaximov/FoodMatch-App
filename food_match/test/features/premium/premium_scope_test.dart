import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/premium/data/premium_repository.dart';
import 'package:food_match/features/premium/domain/effective_entitlements.dart';
import 'package:food_match/features/premium/logic/premium_provider.dart';

class _Repository implements PremiumRepository {
  final requests = <Completer<EffectiveEntitlements>>[];
  @override
  Future<EffectiveEntitlements> fetchMyEntitlements() {
    final request = Completer<EffectiveEntitlements>();
    requests.add(request);
    return request.future;
  }
}

const _pairAccess = EffectiveEntitlements(
  tier: SubscriptionTier.free,
  status: SubscriptionStatus.none,
  features: {PremiumFeature.sharedShoppingList},
  customDishLimit: 3,
);
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('shared permission without a current pair never opens personal grocery', () async {
    final repository = _Repository();
    final provider = PremiumProvider(repository: repository);
    addTearDown(provider.dispose);
    provider.setAuthenticatedUser('free', isAuthenticated: true);
    repository.requests.last.complete(_pairAccess);
    await _flush();
    expect(provider.canUse(PremiumFeature.sharedShoppingList), isFalse);
    expect(provider.canUse(PremiumFeature.shoppingList), isFalse);
  });

  test(
    'pair switch invalidates inherited access and rejects old responses',
    () async {
      final repository = _Repository();
      final provider = PremiumProvider(repository: repository);
      addTearDown(provider.dispose);
      provider.setAuthenticatedUser('free', isAuthenticated: true);
      repository.requests.last.complete(EffectiveEntitlements.free);
      await _flush();
      provider.handlePairContext('pair-a');
      repository.requests.last.complete(_pairAccess);
      await _flush();
      expect(provider.canUse(PremiumFeature.sharedShoppingList), isTrue);
      expect(provider.isPremium, isFalse);
      expect(provider.canUse(PremiumFeature.sessionHistory), isFalse);
      provider.forceRefresh();
      final oldPair = repository.requests.last;
      provider.handlePairContext('pair-b');
      expect(provider.canUse(PremiumFeature.sharedShoppingList), isFalse);
      repository.requests.last.complete(EffectiveEntitlements.free);
      await _flush();
      oldPair.complete(_pairAccess);
      await _flush();
      expect(provider.canUse(PremiumFeature.sharedShoppingList), isFalse);
    },
  );

  test(
    'leaving a pair denies access until refreshed personal capabilities resolve',
    () async {
      final repository = _Repository();
      final provider = PremiumProvider(repository: repository);
      addTearDown(provider.dispose);
      provider.setAuthenticatedUser('paid', isAuthenticated: true);
      provider.handlePairContext('pair-a');
      repository.requests.last.complete(
        const EffectiveEntitlements(
          tier: SubscriptionTier.premium,
          status: SubscriptionStatus.active,
          features: {
            PremiumFeature.advancedFilters,
            PremiumFeature.sharedShoppingList,
          },
          customDishLimit: null,
        ),
      );
      await _flush();
      provider.handlePairContext(null);
      expect(provider.canUse(PremiumFeature.sharedShoppingList), isFalse);
      expect(provider.canUse(PremiumFeature.advancedFilters), isFalse);
      expect(provider.customDishLimit, 3);
      repository.requests.last.complete(
        const EffectiveEntitlements(
          tier: SubscriptionTier.premium,
          status: SubscriptionStatus.active,
          features: {PremiumFeature.advancedFilters},
          customDishLimit: null,
        ),
      );
      await _flush();
      expect(provider.canUse(PremiumFeature.advancedFilters), isTrue);
      expect(provider.customDishLimit, isNull);
    },
  );

  test(
    'force refresh supersedes a running request; logout rejects its response',
    () async {
      final repository = _Repository();
      final provider = PremiumProvider(repository: repository);
      addTearDown(provider.dispose);
      provider.setAuthenticatedUser('user', isAuthenticated: true);
      provider.handlePairContext('pair-a');
      final first = repository.requests.last;
      provider.forceRefresh();
      repository.requests.last.complete(_pairAccess);
      await _flush();
      first.complete(EffectiveEntitlements.free);
      await _flush();
      expect(provider.canUse(PremiumFeature.sharedShoppingList), isTrue);
      provider.forceRefresh();
      provider.clearForLogout();
      repository.requests.last.complete(_pairAccess);
      await _flush();
      expect(provider.canUse(PremiumFeature.sharedShoppingList), isFalse);
      expect(provider.isLoading, isFalse);
    },
  );

  test(
    'rewarded grants are valid, feature-specific, and never make Free Premium',
    () {
      final future = DateTime.now().add(const Duration(hours: 1));
      const grants = {
        PremiumFeature.advancedFilters: 'advanced_filters_once',
        PremiumFeature.shoppingList: 'shopping_list_once',
        PremiumFeature.sessionHistory: 'session_history_once',
        PremiumFeature.smartDeck: 'smart_deck_once',
      };
      for (final grant in grants.entries) {
        final value = EffectiveEntitlements.fromJson({
          'tier': 'free',
          'rewardedGrants': {grant.value: future.toIso8601String()},
        });
        expect(value.canUse(grant.key), isTrue);
        expect(value.isPremium, isFalse);
        expect(value.customDishLimit, 3);
        expect(value.canUse(PremiumFeature.sharedShoppingList), isFalse);
        for (final other in grants.keys.where(
          (feature) => feature != grant.key,
        )) {
          expect(value.canUse(other), isFalse);
        }
        final expired = EffectiveEntitlements.fromJson({
          'rewardedGrants': {
            grant.value: DateTime.now()
                .subtract(const Duration(seconds: 1))
                .toIso8601String(),
          },
        });
        expect(expired.canUse(grant.key), isFalse);
      }
    },
  );
}
