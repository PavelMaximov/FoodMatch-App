import 'effective_entitlements.dart';
abstract interface class AdEligibilityPolicy { bool canRequestExternalAds(EffectiveEntitlements entitlements); }
class PerUserAdEligibilityPolicy implements AdEligibilityPolicy { const PerUserAdEligibilityPolicy(); @override bool canRequestExternalAds(EffectiveEntitlements e)=>!e.isPremium; }
