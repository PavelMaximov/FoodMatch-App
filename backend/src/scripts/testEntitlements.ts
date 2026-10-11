import assert from 'node:assert/strict';
import { EntitlementRepository, EntitlementService } from '../modules/entitlements/services/entitlementService';
import { PerUserAdEligibilityPolicy } from '../modules/entitlements/domain/adEligibilityPolicy';
import { SubscriptionRecord } from '../modules/entitlements/domain/entitlementTypes';
const now=new Date('2026-10-05T00:00:00Z');
const row=(status:SubscriptionRecord['status'],expiresAt=new Date('2026-11-05')):SubscriptionRecord=>({tier:'premium',status,provider:'apple',productId:'premium.monthly',currentPeriodStart:now,expiresAt,trialEndsAt:null,updatedAt:now});
class Repo implements EntitlementRepository {constructor(private values:Record<string,SubscriptionRecord|null>,private fail=false){}async findSubscription(id:string){if(this.fail)throw Error('database unavailable');return this.values[id]??null;}async findActiveGrants(){return [];} }
async function run(){
 const service=new EntitlementService(new Repo({free:null,active:row('active'),trial:row('trialing'),expired:row('active',new Date('2026-01-01'))}));
 const free=await service.getEffectiveEntitlements('free',now),active=await service.getEffectiveEntitlements('active',now),trial=await service.getEffectiveEntitlements('trial',now),expired=await service.getEffectiveEntitlements('expired',now);
 assert.equal(free.isPremium,false);assert.equal(active.isPremium,true);assert.equal(trial.isPremium,true);assert.equal(expired.isPremium,false);assert.equal(active.features.adFree,true);assert.equal(free.features.adFree,false);assert.equal(free.limits.customDishes,3);assert.equal(active.limits.customDishes,null);
 assert.equal(await service.canPairUseFeature({memberIds:['free','active']},'shared_shopping_list'),true);assert.equal((await service.getEffectiveEntitlements('free',now)).isPremium,false);assert.equal((await new EntitlementService(new Repo({},true)).getEffectiveEntitlements('x',now)).isPremium,false);
 assert.equal(new PerUserAdEligibilityPolicy().canRequestExternalAds(active),false);assert.equal(new PerUserAdEligibilityPolicy().canRequestExternalAds(free),true);
 console.log('PASS entitlement domain (11 rules)');
}
run().catch(e=>{console.error(e);process.exit(1);});
