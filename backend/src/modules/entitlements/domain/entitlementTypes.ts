export type SubscriptionTier = 'free' | 'premium';
export type SubscriptionStatus = 'none' | 'trialing' | 'active' | 'grace_period' | 'expired' | 'cancelled';
export type PremiumFeature = 'ad_free' | 'advanced_filters' | 'unlimited_custom_dishes' | 'session_history' | 'shopping_list' | 'shared_shopping_list' | 'smart_deck' | 'recipe_import' | 'favorite_collections' | 'serving_scaling';
export type RewardedFeature = 'advanced_filters_once' | 'shopping_list_once' | 'session_history_once' | 'smart_deck_once';

export interface SubscriptionRecord { tier:SubscriptionTier;status:SubscriptionStatus;provider:string|null;productId:string|null;currentPeriodStart:Date|null;expiresAt:Date|null;trialEndsAt:Date|null;updatedAt:Date }
export interface RewardedGrantRecord { feature:RewardedFeature;createdAt:Date;expiresAt:Date;consumedAt:Date|null;status:'active'|'consumed'|'expired'|'revoked' }
export interface EffectiveEntitlements {
  tier:SubscriptionTier;isPremium:boolean;
  subscription:{status:SubscriptionStatus;productId:string|null;expiresAt:string|null;trialEndsAt:string|null};
  features:{adFree:boolean;advancedFilters:boolean;unlimitedCustomDishes:boolean;sessionHistory:boolean;shoppingList:boolean;sharedShoppingList:boolean;smartDeck:boolean;recipeImport:boolean;favoriteCollections:boolean;servingScaling:boolean};
  limits:{customDishes:number|null};rewardedGrants:Partial<Record<RewardedFeature,string>>;
}
