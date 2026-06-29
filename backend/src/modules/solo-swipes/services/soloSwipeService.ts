import { FilterQuery, Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { DISH_DTO_SELECT, toDishDto, toPublicDishId } from '../../dishes/dto/dishDto';
import { resolveDishByAnyId } from '../../dishes/utils/resolveDishByAnyId';
import { LastFilterPresetService, normalizeFilterList } from '../../filters/services/lastFilterPresetService';
import { SoloSwipeSessionModel } from '../models/SoloSwipeSession';

const MAX_DECK_SIZE = 30;
const EXCLUSION_GROUPS: Record<string,string[]> = { no_meat:['meat','chicken','beef','pork','lamb'], no_dairy:['milk','cheese','cream','butter','yogurt','mozzarella','parmesan','feta'], no_gluten:['flour','bread','pasta','wheat','spaghetti','lasagna sheets','pita','ciabatta'], no_nuts:['peanut','peanuts','almond','almonds','walnut','walnuts','cashew','cashews'], no_seafood:['fish','salmon','shrimp','prawn','prawns','tuna','mussels','seafood'] };
export class SoloSwipeService {
 async getActive(userId:string){ const session = await SoloSwipeSessionModel.findOne({userId:new Types.ObjectId(userId),status:'active'}); if(session){ session.lastActivityAt=new Date(); await session.save(); } return session ? this.toDeck(session) : null; }
 async createSession(userId:string, filter:{cuisines?:string[];moods?:string[];diet?:string[];exclusions?:string[]}){
  await this.assertNoActiveSession(userId);
  const normalized = { cuisines:normalizeFilterList(filter.cuisines), moods:normalizeFilterList(filter.moods), diet:normalizeFilterList(filter.diet), exclusions:normalizeFilterList(filter.exclusions) };
  const dishes = await this.buildDeck(userId, normalized); const now = new Date();
  const session = await SoloSwipeSessionModel.create({userId:new Types.ObjectId(userId), filter:normalized, deckDishIds:dishes.map(d=>d._id as Types.ObjectId), deckIndex:0, lastActivityAt:now});
  return this.toDeck(session, dishes);
 }
 async getDeck(userId:string, sessionId:string){ const session = await this.requireSession(userId, sessionId); session.lastActivityAt=new Date(); await session.save(); return this.toDeck(session); }
 async updateActiveFilter(userId:string, filter:{cuisines?:string[];moods?:string[];diet?:string[];exclusions?:string[]}){
  const session = await SoloSwipeSessionModel.findOne({userId:new Types.ObjectId(userId),status:'active'});
  if(!session) throw new AppError('No active solo session',404,'NO_ACTIVE_SESSION');
  const normalized = { cuisines:normalizeFilterList(filter.cuisines), moods:normalizeFilterList(filter.moods), diet:normalizeFilterList(filter.diet), exclusions:normalizeFilterList(filter.exclusions) };
  const swipedDishIds = new Set(session.swipes.map((s:any)=>s.dishId.toString()));
  const dishes = await this.buildDeck(userId, normalized, swipedDishIds);
  session.filter = normalized;
  session.deckDishIds = dishes.map(d=>d._id as Types.ObjectId);
  session.deckIndex = 0;
  session.matchedCount = session.resultDishIds.length;
  session.lastActivityAt = new Date();
  await session.save();
  return this.toDeck(session, dishes);
 }
 async abandonActive(userId:string){ const session = await SoloSwipeSessionModel.findOne({userId:new Types.ObjectId(userId),status:'active'}); if(!session) return { abandoned:false }; session.status='abandoned'; session.lastActivityAt=new Date(); await session.save(); return { abandoned:true, sessionId: session.id }; }
 async swipe(userId:string, sessionId:string, dishId:string, direction:'like'|'dislike'){
  const session = await this.requireSession(userId, sessionId); const dish = await resolveDishByAnyId(dishId); if(!dish) throw new AppError('This dish is not available.',404);
  const currentId = session.deckDishIds[session.deckIndex]?.toString(); if(!currentId || currentId !== (dish._id as Types.ObjectId).toString()) throw new AppError('Dish is not current in this solo session.',409,'DISH_NOT_CURRENT');
  if(!this.isSoloVisibleDish(dish, userId)) throw new AppError('This dish is not available.',404);
  const already = session.swipes.some(s=>s.dishId.toString()===(dish._id as Types.ObjectId).toString());
  if(!already){ session.swipes.push({dishId:dish._id as Types.ObjectId,direction,createdAt:new Date()}); if(direction==='like' && !session.resultDishIds.some(id=>id.toString()===(dish._id as Types.ObjectId).toString())) session.resultDishIds.push(dish._id as Types.ObjectId); }
  session.deckIndex = Math.min(session.deckIndex + 1, session.deckDishIds.length); session.matchedCount = session.resultDishIds.length; session.lastActivityAt=new Date();
  if(session.deckIndex >= session.deckDishIds.length){ session.status='completed'; session.completedAt=new Date(); await new LastFilterPresetService().saveLast(userId,{mode:'solo',...session.filter,matchedLastTime:session.matchedCount}); }
  await session.save(); return { id: session.id, dishId: toPublicDishId(dish), direction, matchCreated: direction==='like', alreadySwiped: already, completed: session.status==='completed', mode:'solo' };
 }
 async assertNoActiveSession(userId:string){ const [solo, paired] = await Promise.all([SoloSwipeSessionModel.exists({userId:new Types.ObjectId(userId),status:'active'}), CoupleSessionModel.exists({members:new Types.ObjectId(userId),status:'active'})]); if(solo || paired) throw new AppError('You already have an active swipe session.',409,'ACTIVE_SESSION_EXISTS'); }
 private async requireSession(userId:string, sessionId:string){ if(!Types.ObjectId.isValid(sessionId)) throw new AppError('Session not found',404); const session=await SoloSwipeSessionModel.findOne({_id:sessionId,userId:new Types.ObjectId(userId),status:'active'}); if(!session) throw new AppError('No active solo session',404,'NO_ACTIVE_SESSION'); return session; }
 private async toDeck(session:any, loaded?:DishDocument[]){ const ids=session.deckDishIds.slice(session.deckIndex); const dishes = loaded ?? await DishModel.find({_id:{$in:ids}}).select(DISH_DTO_SELECT); const byId=new Map(dishes.map(d=>[d._id.toString(),d])); return { sessionId:session.id, mode:'solo', status:session.status, deckIndex:session.deckIndex, matchedCount:session.matchedCount, filter:session.filter, dishes:ids.map((id:Types.ObjectId)=>byId.get(id.toString())).filter((d: DishDocument | undefined): d is DishDocument => Boolean(d)).map((d: DishDocument)=>toDishDto(d)), meta:{totalCatalogCount:session.deckDishIds.length,candidateCount:session.deckDishIds.length,finalCount:ids.length,usedPartnerChoices:false,bothConfirmed:false} }; }
 private async buildDeck(userId:string, filter:any, excludeDishIds = new Set<string>()){ const query:FilterQuery<DishDocument>={$or:[{visibility:'public',status:'approved'},{isCustom:true,visibility:'private',status:'approved',createdBy:new Types.ObjectId(userId)}]}; const all=await DishModel.find(query).select(DISH_DTO_SELECT); return all.filter(d=>!excludeDishIds.has((d._id as Types.ObjectId).toString())&&this.matches(d,filter)).sort((a,b)=>Number(b.popular)-Number(a.popular)||a._id.toString().localeCompare(b._id.toString())).slice(0,MAX_DECK_SIZE); }
 private isSoloVisibleDish(d:DishDocument,userId:string){ return (d.visibility==='public'&&d.status==='approved') || (d.isCustom&&d.visibility==='private'&&d.status==='approved'&&d.createdBy?.toString()===userId); }
 private matches(d:DishDocument,f:any){ const cuisine=norm(d.cuisine); if(f.cuisines.length && !f.cuisines.includes(cuisine)) return false; const diet=(d.diet??[]).map(norm); if(f.diet.includes('vegan')&&!diet.includes('vegan')) return false; if(f.diet.includes('vegetarian')&&!(diet.includes('vegetarian')||diet.includes('vegan'))) return false; const blocked=f.exclusions.flatMap((e:string)=>EXCLUSION_GROUPS[e]??[]).map(norm); const ings=(d.structuredIngredients?.length?d.structuredIngredients.map(i=>i.name):d.ingredients).map(norm); return !ings.some(i=>blocked.some((b:string)=>i.includes(b))); }
}
function norm(v?:string){return (v??'').trim().toLowerCase().replace(/_/g,' ')}
