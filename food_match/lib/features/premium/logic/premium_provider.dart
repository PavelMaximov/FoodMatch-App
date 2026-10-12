import 'package:flutter/foundation.dart';
import '../data/premium_repository.dart';
import '../domain/ad_eligibility_policy.dart';
import '../domain/effective_entitlements.dart';

class PremiumProvider extends ChangeNotifier {
  PremiumProvider({required PremiumRepository repository,AdEligibilityPolicy adPolicy=const PerUserAdEligibilityPolicy()}):_repository=repository,_adPolicy=adPolicy;
  final PremiumRepository _repository;final AdEligibilityPolicy _adPolicy;
  EffectiveEntitlements _entitlements=EffectiveEntitlements.free;String? _userId;int _generation=0;bool _loading=false;
  EffectiveEntitlements get entitlements=>_entitlements;bool get isPremium=>_entitlements.isPremium;bool get isLoading=>_loading;
  bool canUse(PremiumFeature feature)=>_entitlements.canUse(feature);int? get customDishLimit=>_entitlements.customDishLimit;bool get shouldRequestAds=>_adPolicy.canRequestExternalAds(_entitlements);
  void setAuthenticatedUser(String? userId,{required bool isAuthenticated}){final next=isAuthenticated?userId:null;if(next==_userId)return;_userId=next;_generation++;_entitlements=EffectiveEntitlements.free;_loading=false;notifyListeners();if(next!=null)load();}
  Future<void> load({bool force=false}) async {final user=_userId;if(user==null||(_loading&&!force))return;final request=++_generation;_loading=true;notifyListeners();try{final value=await _repository.fetchMyEntitlements();if(request==_generation&&user==_userId)_entitlements=value;}catch(_){if(request==_generation)_entitlements=EffectiveEntitlements.free;}finally{if(request==_generation){_loading=false;notifyListeners();}}}
  Future<void> forceRefresh()=>load(force:true);
  void clearForLogout(){_userId=null;_generation++;_loading=false;_entitlements=EffectiveEntitlements.free;notifyListeners();}
}
