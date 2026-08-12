import { FilterQuery, Types } from 'mongoose';
import crypto from 'crypto';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { DishDocument, DishModel } from '../../dishes/models/Dish';
import { DISH_DTO_SELECT, toDishDto, toPublicDishId } from '../../dishes/dto/dishDto';
import { resolveDishByAnyId } from '../../dishes/utils/resolveDishByAnyId';
import { LastFilterPresetService, normalizeFilterList } from '../../filters/services/lastFilterPresetService';
import { SwipeModel } from '../../swipes/models/Swipe';
import { dishMatchesExclusions } from '../../../shared/ingredients/exclusionMatcher';
import { buildRecommendedDeck, DeckRecommendationHistoryEntry, RecommendedDeckMeta } from '../../recommendations/deckRecommendationService';
import { logRecommendationMeta } from '../../recommendations/recommendationTypes';
import { SoloSwipeSessionModel } from '../models/SoloSwipeSession';

const MAX_DECK_SIZE = 30;

type SoloFilterInput = { dishRegisters?: string[]; includeCustomDishesFirst?: boolean; cuisines?: string[]; moods?: string[]; diet?: string[]; exclusions?: string[] };
type NormalizedSoloFilter = { dishRegisters: string[]; includeCustomDishesFirst: boolean; cuisines: string[]; moods: string[]; diet: string[]; exclusions: string[] };
type DeckBuildResult = { dishes: DishDocument[]; meta: RecommendedDeckMeta };

export class SoloSwipeService {
 async getActive(userId:string){ const session = await SoloSwipeSessionModel.findOne({userId:new Types.ObjectId(userId),status:'active'}); if(session){ session.lastActivityAt=new Date(); await session.save(); } return session ? this.toDeck(session) : null; }
 async createSession(userId:string, filter:SoloFilterInput){
  await this.assertNoActiveSession(userId);
  const normalized = this.normalizeFilter(filter);
  const result = await this.buildDeck(userId, normalized); const now = new Date();
  logRecommendationMeta(result.meta);
  const session = await SoloSwipeSessionModel.create({userId:new Types.ObjectId(userId), filter:normalized, deckDishIds:result.dishes.map(d=>d._id as Types.ObjectId), deckIndex:0, recommendationMeta: result.meta, lastActivityAt:now});
  return this.toDeck(session, result.dishes, result.meta);
 }
 async getDeck(userId:string, sessionId:string){ const session = await this.requireSession(userId, sessionId); session.lastActivityAt=new Date(); await session.save(); return this.toDeck(session); }
 async updateActiveFilter(userId:string, filter:SoloFilterInput){
  const session = await SoloSwipeSessionModel.findOne({userId:new Types.ObjectId(userId),status:'active'});
  if(!session) throw new AppError('No active solo session',404,'NO_ACTIVE_SESSION');
  const normalized = this.normalizeFilter(filter);
  const swipedDishIds = new Set(session.swipes.map((s:any)=>s.dishId.toString()));
  const currentDeckDishIds = new Set(session.deckDishIds.map((id:Types.ObjectId)=>id.toString()));
  const result = await this.buildDeck(userId, normalized, swipedDishIds, currentDeckDishIds);
  logRecommendationMeta(result.meta, { sessionId: session.id });
  session.filter = normalized;
  session.deckDishIds = result.dishes.map(d=>d._id as Types.ObjectId);
  session.deckIndex = 0;
  session.recommendationMeta = result.meta;
  session.matchedCount = session.resultDishIds.length;
  session.lastActivityAt = new Date();
  await session.save();
  return this.toDeck(session, result.dishes, result.meta);
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
 async undo(userId:string, sessionId:string){
  if(!Types.ObjectId.isValid(sessionId)) throw new AppError('Session not found',404);
  const session = await SoloSwipeSessionModel.findOne({_id:sessionId,userId:new Types.ObjectId(userId),status:{$in:['active','completed']}});
  if(!session) throw new AppError('No solo session found',404,'NO_ACTIVE_SESSION');
  const lastSwipe = session.swipes[session.swipes.length - 1];
  const expectedDishId = session.deckDishIds[session.deckIndex - 1];
  if(!lastSwipe || !expectedDishId || lastSwipe.dishId.toString() !== expectedDishId.toString()) {
   return { undone:false, lastUndoneDishId:null, session:await this.toDeck(session) };
  }
  session.swipes.pop();
  if(lastSwipe.direction === 'like') session.resultDishIds = session.resultDishIds.filter(id=>id.toString() !== lastSwipe.dishId.toString());
  session.deckIndex -= 1;
  session.matchedCount = session.resultDishIds.length;
  session.status = 'active';
  session.completedAt = null;
  session.lastActivityAt = new Date();
  await session.save();
  return { undone:true, lastUndoneDishId:toPublicDishId(lastSwipe.dishId), session:await this.toDeck(session) };
 }
 async assertNoActiveSession(userId:string){ const [solo, paired] = await Promise.all([SoloSwipeSessionModel.exists({userId:new Types.ObjectId(userId),status:'active'}), CoupleSessionModel.exists({members:new Types.ObjectId(userId),status:'active'})]); if(solo || paired) throw new AppError('You already have an active swipe session.',409,'ACTIVE_SESSION_EXISTS'); }
 private normalizeFilter(filter:SoloFilterInput): NormalizedSoloFilter { return { dishRegisters:normalizeFilterList(filter.dishRegisters), includeCustomDishesFirst:filter.includeCustomDishesFirst === true, cuisines:normalizeFilterList(filter.cuisines), moods:normalizeFilterList(filter.moods), diet:normalizeFilterList(filter.diet), exclusions:normalizeFilterList(filter.exclusions) }; }
 private async requireSession(userId:string, sessionId:string){ if(!Types.ObjectId.isValid(sessionId)) throw new AppError('Session not found',404); const session=await SoloSwipeSessionModel.findOne({_id:sessionId,userId:new Types.ObjectId(userId),status:'active'}); if(!session) throw new AppError('No active solo session',404,'NO_ACTIVE_SESSION'); return session; }
 private async toDeck(session:any, loaded?:DishDocument[], recommendationMeta?: RecommendedDeckMeta){ recommendationMeta = recommendationMeta ?? session.recommendationMeta; const ids=session.deckDishIds.slice(session.deckIndex); const dishes = loaded ?? await DishModel.find({_id:{$in:ids}}).select(DISH_DTO_SELECT); const byId=new Map(dishes.map(d=>[d._id.toString(),d])); return { sessionId:session.id, mode:'solo', status:session.status, deckIndex:session.deckIndex, matchedCount:session.matchedCount, filter:session.filter, dishes:ids.map((id:Types.ObjectId)=>byId.get(id.toString())).filter((d: DishDocument | undefined): d is DishDocument => Boolean(d)).map((d: DishDocument)=>toDishDto(d)), meta:{totalCatalogCount:recommendationMeta?.totalCatalogCount ?? session.deckDishIds.length,candidateCount:recommendationMeta?.candidateCount ?? session.deckDishIds.length,finalCount:ids.length,usedPartnerChoices:false,bothConfirmed:false,...(recommendationMeta ? { recommendationMeta, algorithm: recommendationMeta.algorithm, excludedByExclusionsCount: recommendationMeta.excludedByExclusionsCount, candidateCountAfterExclusions: recommendationMeta.candidateCountAfterExclusions, expansionApplied: recommendationMeta.expansionApplied, expansionReason: recommendationMeta.expansionReason ?? null, diagnosticsNotes: recommendationMeta.diagnosticsNotes ?? [] } : {})} }; }
 private async buildDeck(userId:string, filter:NormalizedSoloFilter, excludeDishIds = new Set<string>(), recentlySeenDishIds = new Set<string>()): Promise<DeckBuildResult>{
  const query:FilterQuery<DishDocument>={$or:[{visibility:'public',status:'approved'},{isCustom:true,status:'approved',createdBy:new Types.ObjectId(userId)}]};
  const [all, history] = await Promise.all([DishModel.find(query).select(DISH_DTO_SELECT), this.loadUserHistory(userId)]);
  const result = buildRecommendedDeck({ userId, dishes: all, filters: filter, userHistory: history, recentlySeenDishIds, excludedDishIds: excludeDishIds, deckSize: MAX_DECK_SIZE, mode: 'solo' });
  result.dishes = shuffleWithinScoreBands(result.dishes, crypto.randomUUID());
  if (!filter.includeCustomDishesFirst) return result;
  const custom = all.filter((dish) => dish.isCustom === true && dish.createdBy?.toString() === userId && !excludeDishIds.has(dish._id.toString()) && !dishMatchesExclusions(dish, filter.exclusions) && matchesCustomDiet(dish, filter.diet)).sort((a,b) => b.createdAt.getTime() - a.createdAt.getTime());
  const customIds = new Set(custom.map((dish) => dish._id.toString()));
  const discoveryTarget = Math.max(1, Math.floor(MAX_DECK_SIZE * 0.2));
  const customPrefix = custom.length >= MAX_DECK_SIZE - discoveryTarget ? custom.slice(0, MAX_DECK_SIZE - discoveryTarget) : custom;
  const tailTarget = MAX_DECK_SIZE - customPrefix.length;
  const tail = result.dishes.filter((dish) => !customIds.has(dish._id.toString())).slice(0, Math.max(0, tailTarget));
  return { ...result, dishes: [...customPrefix, ...tail], meta: { ...result.meta, finalCount: customPrefix.length + tail.length, customIncludedCount: customPrefix.length } };
 }
 private async loadUserHistory(userId:string): Promise<DeckRecommendationHistoryEntry[]> {
  const userObjectId = new Types.ObjectId(userId);
  const [soloSessions, pairedSwipes] = await Promise.all([
   SoloSwipeSessionModel.find({ userId: userObjectId, swipes: { $ne: [] } }).select('swipes').populate({ path: 'swipes.dishId', select: DISH_DTO_SELECT }).sort({ updatedAt: -1 }).limit(20).lean(),
   SwipeModel.find({ userId: userObjectId }).select('dishId direction').populate({ path: 'dishId', select: DISH_DTO_SELECT }).sort({ createdAt: -1 }).limit(100).lean()
  ]);
  const history: DeckRecommendationHistoryEntry[] = [];
  for (const session of soloSessions as any[]) {
   for (const swipe of session.swipes ?? []) {
    if (swipe?.dishId && (swipe.direction === 'like' || swipe.direction === 'dislike')) history.push({ dish: swipe.dishId as DishDocument, direction: swipe.direction });
   }
  }
  for (const swipe of pairedSwipes as any[]) {
   if (swipe?.dishId && (swipe.direction === 'like' || swipe.direction === 'dislike')) history.push({ dish: swipe.dishId as DishDocument, direction: swipe.direction });
  }
  return history;
 }
 private isSoloVisibleDish(d:DishDocument,userId:string){ return (d.visibility==='public'&&d.status==='approved') || (d.isCustom&&d.status==='approved'&&d.createdBy?.toString()===userId); }
}

function matchesCustomDiet(dish: DishDocument, diet: string[]) { const values = new Set((dish.diet ?? []).map((value) => value.trim().toLowerCase())); if (diet.includes('vegan')) return values.has('vegan'); if (diet.includes('vegetarian')) return values.has('vegetarian') || values.has('vegan'); return true; }

function shuffleWithinScoreBands(dishes: DishDocument[], seed: string) {
 return dishes.flatMap((_, start) => start % 4 === 0 ? seededShuffle(dishes.slice(start, start + 4), `${seed}:${start}`) : []);
}

function seededShuffle<T>(items: T[], seed: string) {
 const result = [...items];
 let state = crypto.createHash('sha1').update(seed).digest().readUInt32BE(0);
 for (let index = result.length - 1; index > 0; index -= 1) {
  state = (state * 1664525 + 1013904223) >>> 0;
  const target = state % (index + 1);
  [result[index], result[target]] = [result[target], result[index]];
 }
 return result;
}
