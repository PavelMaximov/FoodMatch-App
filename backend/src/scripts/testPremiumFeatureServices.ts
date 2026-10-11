import assert from 'node:assert/strict';
import { AppError } from '../core/errors/AppError';
import { CoupleSessionRecord } from '../domain/repositories/types';
import { requireAdvancedFilterAccess } from '../modules/entitlements/services/featureAccessService';
import { MatchService } from '../modules/matches/services/matchService';
import { SharedShoppingListService } from '../modules/shopping-list/services/sharedShoppingListService';

const pair=(id:string,members:string[]):CoupleSessionRecord=>({id,inviteCode:'TEST',status:'active',createdBy:members[0],memberIds:members,pairKey:null,preparedDeckDishIds:[],preparedDeckGeneration:0,preparedDeckFiltersHash:null,preparedDeckMeta:{},restartState:{},pairLifecycleState:{},createdAt:new Date(),updatedAt:new Date(),closedAt:null});
async function rejectsCode(task:()=>Promise<unknown>,code:string){await assert.rejects(task,(error:unknown)=>error instanceof AppError&&error.code===code);}

async function advancedAuthorization(){
 const denied={canUseFeature:async()=>false};
 await rejectsCode(()=>requireAdvancedFilterAccess('free',{maxCookTime:30},denied as any),'PREMIUM_ADVANCED_FILTERS_REQUIRED');
 await requireAdvancedFilterAccess('free',{diet:['vegan'],exclusions:['nuts']},denied as any);
 await requireAdvancedFilterAccess('premium',{season:['summer']},{canUseFeature:async()=>true} as any);
}

async function shoppingListAuthorization(){
 const active=pair('pair-new',['premium','free']);let addWrites=0;
 const query=async(text:string)=>{if(text.startsWith('insert')){addWrites++;return{rows:[],rowCount:1} as any;}if(text.startsWith('select'))return{rows:[],rowCount:0} as any;return{rows:[],rowCount:0} as any;};
 const accepted=(user:string)=>new SharedShoppingListService({findActive:async()=>active,canPair:async()=>true,query:query as any});
 await accepted('premium').list('premium');await accepted('free').list('free');
 await accepted('premium').add('premium',{name:'Milk'});await accepted('free').add('free',{name:'milk'});assert.equal(addWrites,2,'duplicate adds use the database upsert path');
 await rejectsCode(()=>new SharedShoppingListService({findActive:async()=>active,canPair:async()=>false}).list('free'),'PREMIUM_SHOPPING_LIST_REQUIRED');
 await rejectsCode(()=>new SharedShoppingListService({findActive:async()=>null,canPair:async()=>true}).list('outsider'),'PAIR_SESSION_INACTIVE');
 await rejectsCode(()=>accepted('free').update('free','old-item',{checked:true}),'SHOPPING_LIST_ITEM_NOT_FOUND');
 await rejectsCode(()=>accepted('free').remove('free','old-item'),'SHOPPING_LIST_ITEM_NOT_FOUND');
 const client={query:async(text:string)=>text.startsWith('select id')?{rows:[{id:'mine'}]}:{rows:[]},release(){}};
 const reorder=new SharedShoppingListService({findActive:async()=>active,canPair:async()=>true,connect:async()=>client});
 await rejectsCode(()=>reorder.reorder('free',['foreign']),'SHOPPING_LIST_REORDER_SCOPE_MISMATCH');
}

async function historyAuthorization(){
 const free=new MatchService({requireFeature:async()=>{throw new AppError('Premium required',403,'PREMIUM_SESSION_HISTORY_REQUIRED');}});
 await rejectsCode(()=>free.historyForUser('free'),'PREMIUM_SESSION_HISTORY_REQUIRED');
 const rows:any[]=[{session_id:'solo-own',mode:'solo',started_at:new Date(),completed_at:new Date(),session_status:'completed',partner_name:null,dish_count:1,preview_dish_ids:[],dish_ids:['dish']},{session_id:'pair-own',mode:'pair',started_at:new Date(),completed_at:new Date(),session_status:'closed',partner_name:'Partner',dish_count:1,preview_dish_ids:[],dish_ids:['dish']}];
 const query=async(_text:string,values?:readonly unknown[])=>({rows:rows.filter(row=>row.session_id===values?.[1]),rowCount:1} as any);
 const service=new MatchService({requireFeature:async()=>undefined,query:query as any,loadDishes:async()=>[]});
 assert.equal((await service.historySessionForUser('owner','solo-own')).mode,'solo');
 assert.equal((await service.historySessionForUser('member','pair-own')).mode,'pair');
 await rejectsCode(()=>service.historySessionForUser('outsider','pair-other'),'SESSION_HISTORY_NOT_FOUND');
}

Promise.all([advancedAuthorization(),shoppingListAuthorization(),historyAuthorization()]).then(()=>console.log('PASS Premium feature service authorization')).catch((error)=>{console.error(error);process.exit(1);});
