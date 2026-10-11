import '../../../data/services/api_service.dart';
import '../domain/effective_entitlements.dart';
abstract interface class PremiumRepository { Future<EffectiveEntitlements> fetchMyEntitlements(); }
class ApiPremiumRepository implements PremiumRepository { ApiPremiumRepository(this._api);final ApiService _api;@override Future<EffectiveEntitlements> fetchMyEntitlements() async {final value=await _api.get('/entitlements/me');return EffectiveEntitlements.fromJson(Map<String,dynamic>.from(value as Map));} }
