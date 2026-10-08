import { queryPostgres } from '../../../shared/db/postgresClient';
import { CoupleSessionRecord } from '../../../domain/repositories/types';
import { EffectiveEntitlements, PremiumFeature, RewardedGrantRecord, SubscriptionRecord } from '../domain/entitlementTypes';

export interface EntitlementRepository { findSubscription(userId:string):Promise<SubscriptionRecord|null>; findActiveGrants(userId:string,now:Date):Promise<RewardedGrantRecord[]> }

export class PostgresEntitlementRepository implements EntitlementRepository {
  async findSubscription(userId:string){const r=await queryPostgres<any>('select tier,status,provider,product_id,current_period_start,expires_at,trial_ends_at,updated_at from user_subscriptions where user_id=$1',[userId]);const x=r.rows[0];return x?{tier:x.tier,status:x.status,provider:x.provider,productId:x.product_id,currentPeriodStart:x.current_period_start,expiresAt:x.expires_at,trialEndsAt:x.trial_ends_at,updatedAt:x.updated_at}:null;}
  async findActiveGrants(userId:string,now:Date){const r=await queryPostgres<any>("select feature,created_at,expires_at,consumed_at,status from rewarded_feature_grants where user_id=$1 and status='active' and consumed_at is null and expires_at>$2",[userId,now]);return r.rows.map(x=>({feature:x.feature,createdAt:x.created_at,expiresAt:x.expires_at,consumedAt:x.consumed_at,status:x.status}));}
}

const premiumFeatures = {adFree:true,advancedFilters:true,unlimitedCustomDishes:true,sessionHistory:true,shoppingList:true,sharedShoppingList:true,smartDeck:true,recipeImport:true,favoriteCollections:true,servingScaling:true};
const freeFeatures = {adFree:false,advancedFilters:false,unlimitedCustomDishes:false,sessionHistory:false,shoppingList:false,sharedShoppingList:false,smartDeck:false,recipeImport:false,favoriteCollections:false,servingScaling:false};

export class EntitlementService {
  constructor(private readonly repository:EntitlementRepository=new PostgresEntitlementRepository()){}
  async getEffectiveEntitlements(userId:string,now=new Date()):Promise<EffectiveEntitlements>{
    // Fail closed: callers receive Free if entitlement storage is unavailable.
    try { return this.compute(await this.repository.findSubscription(userId),await this.repository.findActiveGrants(userId,now),now); }
    catch(error){console.error('[Entitlements] resolution failed; denying Premium',error);return this.compute(null,[],now);}
  }
  compute(subscription:SubscriptionRecord|null,grants:RewardedGrantRecord[]=[],now=new Date()):EffectiveEntitlements{
    const status=subscription?.status??'none';
    const validStatus=status==='active'||status==='trialing';
    const notExpired=!subscription?.expiresAt||subscription.expiresAt.getTime()>now.getTime();
    const isPremium=subscription?.tier==='premium'&&validStatus&&notExpired;
    return {tier:isPremium?'premium':'free',isPremium,subscription:{status,productId:subscription?.productId??null,expiresAt:subscription?.expiresAt?.toISOString()??null,trialEndsAt:subscription?.trialEndsAt?.toISOString()??null},features:{...(isPremium?premiumFeatures:freeFeatures)},limits:{customDishes:isPremium?null:3},rewardedGrants:Object.fromEntries(grants.filter(g=>g.status==='active'&&!g.consumedAt&&g.expiresAt>now).map(g=>[g.feature,g.expiresAt.toISOString()]))};
  }
  async canPairUseFeature(session:Pick<CoupleSessionRecord,'memberIds'>,feature:PremiumFeature){if(feature!=='shared_shopping_list')return false;const members=await Promise.all(session.memberIds.map(id=>this.getEffectiveEntitlements(id)));return members.some(x=>x.features.sharedShoppingList);}
}

export const entitlementService=new EntitlementService();
