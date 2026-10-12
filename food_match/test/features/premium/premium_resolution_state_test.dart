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

const _premium = EffectiveEntitlements(
  tier: SubscriptionTier.premium,
  status: SubscriptionStatus.active,
  features: {
    PremiumFeature.adFree,
    PremiumFeature.advancedFilters,
    PremiumFeature.sharedShoppingList,
  },
  customDishLimit: null,
);
Future<void> _flush() => Future<void>.delayed(Duration.zero);
void _expectDenied(PremiumProvider provider) {
  expect(provider.shouldRequestAds, isFalse);
  expect(provider.isPremium, isFalse);
  expect(provider.canUse(PremiumFeature.advancedFilters), isFalse);
  expect(provider.entitlements.canUse(PremiumFeature.advancedFilters), isFalse);
  expect(provider.customDishLimit, 3);
}

void main() {
  late _Repository repository;
  late PremiumProvider provider;
  setUp(() {
    repository = _Repository();
    provider = PremiumProvider(repository: repository);
  });
  tearDown(() => provider.dispose());

  test(
    'new unresolved provider cannot request ads or expose Premium access',
    () {
      expect(provider.resolutionState, EntitlementResolutionState.unresolved);
      _expectDenied(provider);
    },
  );
  test('loading denies previously resolved Premium access and ads', () async {
    provider.setAuthenticatedUser('a', isAuthenticated: true);
    repository.requests.last.complete(_premium);
    await _flush();
    expect(provider.canUse(PremiumFeature.advancedFilters), isTrue);
    final refresh = provider.forceRefresh();
    expect(provider.resolutionState, EntitlementResolutionState.loading);
    _expectDenied(provider);
    repository.requests.last.complete(_premium);
    await refresh;
    expect(provider.canUse(PremiumFeature.advancedFilters), isTrue);
  });
  test('request error denies ads and Premium access', () async {
    provider.setAuthenticatedUser('a', isAuthenticated: true);
    repository.requests.last.completeError(
      StateError('entitlements unavailable'),
    );
    await _flush();
    expect(provider.resolutionState, EntitlementResolutionState.error);
    expect(provider.isLoading, isFalse);
    _expectDenied(provider);
  });
  test('confirmed Free enables ad requests', () async {
    provider.setAuthenticatedUser('a', isAuthenticated: true);
    _expectDenied(provider);
    repository.requests.last.complete(EffectiveEntitlements.free);
    await _flush();
    expect(provider.resolutionState, EntitlementResolutionState.ready);
    expect(provider.shouldRequestAds, isTrue);
    expect(provider.isPremium, isFalse);
  });
  test('confirmed Premium denies ads and enables its features', () async {
    provider.setAuthenticatedUser('a', isAuthenticated: true);
    repository.requests.last.complete(_premium);
    await _flush();
    expect(provider.resolutionState, EntitlementResolutionState.ready);
    expect(provider.shouldRequestAds, isFalse);
    expect(provider.isPremium, isTrue);
    expect(provider.canUse(PremiumFeature.advancedFilters), isTrue);
  });
  test(
    'account switch and stale previous-user Free response cannot enable ads',
    () async {
      provider.setAuthenticatedUser('a', isAuthenticated: true);
      repository.requests.last.complete(EffectiveEntitlements.free);
      await _flush();
      expect(provider.shouldRequestAds, isTrue);
      provider.forceRefresh();
      final stale = repository.requests.last;
      provider.setAuthenticatedUser('b', isAuthenticated: true);
      _expectDenied(provider);
      stale.complete(EffectiveEntitlements.free);
      await _flush();
      expect(provider.resolutionState, EntitlementResolutionState.loading);
      _expectDenied(provider);
      repository.requests.last.complete(_premium);
      await _flush();
      expect(provider.isPremium, isTrue);
      expect(provider.shouldRequestAds, isFalse);
    },
  );
  test('logout blocks ads even when a pending Free response arrives', () async {
    provider.setAuthenticatedUser('a', isAuthenticated: true);
    repository.requests.last.complete(EffectiveEntitlements.free);
    await _flush();
    expect(provider.shouldRequestAds, isTrue);
    provider.forceRefresh();
    final stale = repository.requests.last;
    provider.clearForLogout();
    _expectDenied(provider);
    stale.complete(EffectiveEntitlements.free);
    await _flush();
    expect(provider.resolutionState, EntitlementResolutionState.unresolved);
    _expectDenied(provider);
  });
  test(
    'pair changes and refresh failures never expose stale ad eligibility',
    () async {
      provider.setAuthenticatedUser('a', isAuthenticated: true);
      repository.requests.last.complete(EffectiveEntitlements.free);
      await _flush();
      expect(provider.shouldRequestAds, isTrue);
      provider.handlePairContext('pair-a');
      _expectDenied(provider);
      repository.requests.last.completeError(StateError('refresh failed'));
      await _flush();
      expect(provider.resolutionState, EntitlementResolutionState.error);
      _expectDenied(provider);
      provider.handlePairContext('pair-b');
      _expectDenied(provider);
      repository.requests.last.complete(EffectiveEntitlements.free);
      await _flush();
      expect(provider.shouldRequestAds, isTrue);
    },
  );
}
