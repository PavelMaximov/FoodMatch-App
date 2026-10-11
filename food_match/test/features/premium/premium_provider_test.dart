import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_match/features/premium/data/premium_repository.dart';
import 'package:food_match/features/premium/domain/effective_entitlements.dart';
import 'package:food_match/features/premium/logic/premium_provider.dart';

class FakeRepository implements PremiumRepository {FakeRepository(this.responses);final List<Future<EffectiveEntitlements>> responses;int index=0;@override Future<EffectiveEntitlements> fetchMyEntitlements()=>responses[index++];}
const premium=EffectiveEntitlements(tier:SubscriptionTier.premium,status:SubscriptionStatus.active,features:{PremiumFeature.adFree,PremiumFeature.advancedFilters,PremiumFeature.unlimitedCustomDishes,PremiumFeature.sessionHistory,PremiumFeature.shoppingList,PremiumFeature.sharedShoppingList},customDishLimit:null);
void main(){
 test('defaults safely to Free and exposes free policy',(){final p=PremiumProvider(repository:FakeRepository([]));expect(p.isPremium,isFalse);expect(p.customDishLimit,3);expect(p.shouldRequestAds,isTrue);expect(p.canUse(PremiumFeature.advancedFilters),isFalse);});
 test('premium response exposes gates, limit, and ad policy',()async{final p=PremiumProvider(repository:FakeRepository([Future.value(premium)]));p.setAuthenticatedUser('a',isAuthenticated:true);await Future<void>.delayed(Duration.zero);expect(p.isPremium,isTrue);expect(p.canUse(PremiumFeature.advancedFilters),isTrue);expect(p.customDishLimit,isNull);expect(p.shouldRequestAds,isFalse);});
 test('logout clears entitlement',()async{final p=PremiumProvider(repository:FakeRepository([Future.value(premium)]));p.setAuthenticatedUser('a',isAuthenticated:true);await Future<void>.delayed(Duration.zero);p.clearForLogout();expect(p.isPremium,isFalse);});
 test('stale account A response cannot populate account B',()async{final a=Completer<EffectiveEntitlements>(),b=Completer<EffectiveEntitlements>();final p=PremiumProvider(repository:FakeRepository([a.future,b.future]));p.setAuthenticatedUser('a',isAuthenticated:true);p.setAuthenticatedUser('b',isAuthenticated:true);b.complete(EffectiveEntitlements.free);await Future<void>.delayed(Duration.zero);a.complete(premium);await Future<void>.delayed(Duration.zero);expect(p.isPremium,isFalse);});
 test('JSON free and premium responses map capabilities',(){final free=EffectiveEntitlements.fromJson({'tier':'free','subscription':{'status':'none'},'features':{'adFree':false},'limits':{'customDishes':3},'rewardedGrants':{}});final paid=EffectiveEntitlements.fromJson({'tier':'premium','subscription':{'status':'active'},'features':{'adFree':true,'shoppingList':true},'limits':{'customDishes':null}});expect(free.customDishLimit,3);expect(paid.canUse(PremiumFeature.shoppingList),isTrue);});
 test('feature-specific grant does not make user Premium',(){final granted=EffectiveEntitlements(tier:SubscriptionTier.free,status:SubscriptionStatus.none,features:const {},customDishLimit:3,rewardedGrants:{'shopping_list_once':DateTime.now().add(const Duration(minutes:5))});expect(granted.isPremium,isFalse);expect(granted.canUse(PremiumFeature.shoppingList),isTrue);expect(granted.canUse(PremiumFeature.sessionHistory),isFalse);});
}
