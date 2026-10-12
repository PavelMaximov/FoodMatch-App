import 'package:flutter/foundation.dart';
import '../data/premium_repository.dart';
import '../domain/ad_eligibility_policy.dart';
import '../domain/effective_entitlements.dart';

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
  bool _loading = false;
  bool _disposed = false;

  EffectiveEntitlements get entitlements => _entitlements;
  bool get isPremium => _entitlements.isPremium;
  bool get isLoading => _loading;
  bool canUse(PremiumFeature feature) => _entitlements.canUse(feature);
  int? get customDishLimit => _entitlements.customDishLimit;
  bool get shouldRequestAds => _adPolicy.canRequestExternalAds(_entitlements);

  void setAuthenticatedUser(String? userId, {required bool isAuthenticated}) {
    final next = isAuthenticated ? userId : null;
    if (_disposed || next == _userId) return;
    _userId = next;
    _pairSessionId = null;
    _generation++;
    _entitlements = EffectiveEntitlements.free;
    _loading = false;
    notifyListeners();
    if (next != null) load();
  }

  void handlePairContext(String? sessionId) {
    final next = _userId == null ? null : sessionId;
    if (_disposed || next == _pairSessionId) return;
    _pairSessionId = next;
    _generation++;
    _loading = false;
    // Remove access inherited from the old pair immediately, while preserving
    // the user's own capabilities, grants and custom-dish limit.
    _entitlements = _entitlements.withoutSharedShoppingList();
    notifyListeners();
    if (_userId != null) load(force: true);
  }

  Future<void> load({bool force = false}) async {
    final user = _userId;
    final pair = _pairSessionId;
    if (_disposed || user == null || (_loading && !force)) return;
    final request = ++_generation;
    _loading = true;
    notifyListeners();
    bool isCurrent() =>
        !_disposed &&
        request == _generation &&
        user == _userId &&
        pair == _pairSessionId;
    try {
      final value = await _repository.fetchMyEntitlements();
      if (isCurrent()) _entitlements = value;
    } catch (_) {
      if (isCurrent()) _entitlements = EffectiveEntitlements.free;
    } finally {
      if (isCurrent()) {
        _loading = false;
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
    _loading = false;
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
