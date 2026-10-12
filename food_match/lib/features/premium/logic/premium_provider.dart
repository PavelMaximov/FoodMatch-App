import 'package:flutter/foundation.dart';
import '../data/premium_repository.dart';
import '../domain/ad_eligibility_policy.dart';
import '../domain/effective_entitlements.dart';

enum EntitlementResolutionState { unresolved, loading, ready, error }

class PremiumProvider extends ChangeNotifier {
  PremiumProvider({
    required PremiumRepository repository,
    AdEligibilityPolicy adPolicy = const PerUserAdEligibilityPolicy(),
  }) : _repository = repository,
       _adPolicy = adPolicy;

  final PremiumRepository _repository;
  final AdEligibilityPolicy _adPolicy;
  EffectiveEntitlements _entitlements = EffectiveEntitlements.free;
  String? _userId;
  String? _pairSessionId;
  int _generation = 0;
  EntitlementResolutionState _resolutionState =
      EntitlementResolutionState.unresolved;
  bool _disposed = false;

  EntitlementResolutionState get resolutionState => _resolutionState;
  bool get _isReady => _resolutionState == EntitlementResolutionState.ready;
  EffectiveEntitlements get entitlements =>
      _isReady ? _entitlements : EffectiveEntitlements.free;
  bool get isPremium => entitlements.isPremium;
  bool get isLoading => _resolutionState == EntitlementResolutionState.loading;
  bool canUse(PremiumFeature feature) =>
      _isReady && _entitlements.canUse(feature);
  int? get customDishLimit => entitlements.customDishLimit;
  bool get shouldRequestAds =>
      _isReady && _adPolicy.canRequestExternalAds(_entitlements);

  void setAuthenticatedUser(String? userId, {required bool isAuthenticated}) {
    final next = isAuthenticated ? userId : null;
    if (_disposed || next == _userId) return;
    _userId = next;
    _pairSessionId = null;
    _generation++;
    _entitlements = EffectiveEntitlements.free;
    _resolutionState = EntitlementResolutionState.unresolved;
    notifyListeners();
    if (next != null) load();
  }

  void handlePairContext(String? sessionId) {
    final next = _userId == null ? null : sessionId;
    if (_disposed || next == _pairSessionId) return;
    _pairSessionId = next;
    _generation++;
    _resolutionState = EntitlementResolutionState.unresolved;
    // Remove access inherited from the old pair immediately, while preserving
    // the user's snapshot for the next response. Public access stays denied
    // until the refreshed entitlement is ready.
    _entitlements = _entitlements.withoutSharedShoppingList();
    notifyListeners();
    if (_userId != null) load(force: true);
  }

  Future<void> load({bool force = false}) async {
    final user = _userId;
    final pair = _pairSessionId;
    if (_disposed || user == null || (isLoading && !force)) return;
    final request = ++_generation;
    _resolutionState = EntitlementResolutionState.loading;
    notifyListeners();
    bool isCurrent() =>
        !_disposed &&
        request == _generation &&
        user == _userId &&
        pair == _pairSessionId;
    try {
      final value = await _repository.fetchMyEntitlements();
      if (isCurrent()) {
        _entitlements = value;
        _resolutionState = EntitlementResolutionState.ready;
      }
    } catch (_) {
      if (isCurrent()) {
        _entitlements = EffectiveEntitlements.free;
        _resolutionState = EntitlementResolutionState.error;
      }
    } finally {
      if (isCurrent()) {
        notifyListeners();
      }
    }
  }

  Future<void> forceRefresh() => load(force: true);
  void clearForLogout() {
    if (_disposed) return;
    _userId = null;
    _pairSessionId = null;
    _generation++;
    _resolutionState = EntitlementResolutionState.unresolved;
    _entitlements = EffectiveEntitlements.free;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
