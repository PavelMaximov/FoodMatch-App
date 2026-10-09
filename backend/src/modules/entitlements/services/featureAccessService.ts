import { AppError } from '../../../core/errors/AppError';
import { entitlementService } from './entitlementService';

export const ADVANCED_FILTER_KEYS=['maxCookTime','maxTotalTime','minCalories','maxCalories','calories','effort','ingredients','season'] as const;

export function hasAdvancedFilters(payload:unknown):boolean{
  if(!payload||typeof payload!=='object')return false;
  const value=payload as Record<string,unknown>;
  return ADVANCED_FILTER_KEYS.some(key=>Array.isArray(value[key])?value[key]!.length>0:value[key]!==undefined&&value[key]!==null&&value[key]!=='');
}

export async function requireAdvancedFilterAccess(userId:string,payload:unknown):Promise<void>{
  if(!hasAdvancedFilters(payload))return;
  if(!await entitlementService.canUseFeature(userId,'advanced_filters'))throw new AppError('FoodMatch Premium is required for advanced filters.',403,'PREMIUM_ADVANCED_FILTERS_REQUIRED',{feature:'advanced_filters'});
}

export async function requirePremiumFeature(userId:string,feature:'shopping_list'|'session_history',code:string):Promise<void>{
  if(!await entitlementService.canUseFeature(userId,feature))throw new AppError('FoodMatch Premium is required for this feature.',403,code,{feature});
}
