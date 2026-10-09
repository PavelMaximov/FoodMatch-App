import { EffectiveEntitlements } from './entitlementTypes';
export interface AdEligibilityPolicy { canRequestExternalAds(entitlements:EffectiveEntitlements):boolean }
export class PerUserAdEligibilityPolicy implements AdEligibilityPolicy { canRequestExternalAds(e:EffectiveEntitlements){return !e.isPremium;} }
