enum PremiumFeature { adFree, advancedFilters, unlimitedCustomDishes, sessionHistory, shoppingList, sharedShoppingList, smartDeck, recipeImport, favoriteCollections, servingScaling }
enum SubscriptionTier { free, premium }
enum SubscriptionStatus { none, trialing, active, gracePeriod, expired, cancelled }

class EffectiveEntitlements {
  const EffectiveEntitlements({required this.tier,required this.status,required this.features,required this.customDishLimit,this.rewardedGrants=const <String,DateTime>{}});
  static const free=EffectiveEntitlements(tier:SubscriptionTier.free,status:SubscriptionStatus.none,features:<PremiumFeature>{},customDishLimit:3);
  final SubscriptionTier tier; final SubscriptionStatus status; final Set<PremiumFeature> features; final int? customDishLimit; final Map<String,DateTime> rewardedGrants;
  bool get isPremium=>tier==SubscriptionTier.premium;
  bool canUse(PremiumFeature feature)=>features.contains(feature);
  factory EffectiveEntitlements.fromJson(Map<String,dynamic> json){
    final f=Map<String,dynamic>.from(json['features'] as Map? ?? const {});
    const names=<PremiumFeature,String>{PremiumFeature.adFree:'adFree',PremiumFeature.advancedFilters:'advancedFilters',PremiumFeature.unlimitedCustomDishes:'unlimitedCustomDishes',PremiumFeature.sessionHistory:'sessionHistory',PremiumFeature.shoppingList:'shoppingList',PremiumFeature.sharedShoppingList:'sharedShoppingList',PremiumFeature.smartDeck:'smartDeck',PremiumFeature.recipeImport:'recipeImport',PremiumFeature.favoriteCollections:'favoriteCollections',PremiumFeature.servingScaling:'servingScaling'};
    final subscription=Map<String,dynamic>.from(json['subscription'] as Map? ?? const {});final limits=Map<String,dynamic>.from(json['limits'] as Map? ?? const {});
    final tier=json['tier']=='premium'?SubscriptionTier.premium:SubscriptionTier.free;
    return EffectiveEntitlements(tier:tier,status:SubscriptionStatus.values.firstWhere((x)=>_statusName(x)==subscription['status'],orElse:()=>SubscriptionStatus.none),features:{for(final e in names.entries)if(f[e.value]==true)e.key},customDishLimit:tier==SubscriptionTier.premium?null:(limits['customDishes'] is num?(limits['customDishes'] as num).toInt():3),rewardedGrants:{for(final e in Map<String,dynamic>.from(json['rewardedGrants'] as Map? ?? const {}).entries)if(DateTime.tryParse('${e.value}') case final date?)e.key:date});
  }
  static String _statusName(SubscriptionStatus s)=>s==SubscriptionStatus.gracePeriod?'grace_period':s.name;
}
