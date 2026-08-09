import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { LastFilterPresetModel } from '../models/LastFilterPreset';

export interface LastFilterPayload { mode:'solo'|'paired'; dishRegisters?:string[]; includeCustomDishesFirst?:boolean; cuisines?:string[]; moods?:string[]; diet?:string[]; exclusions?:string[]; matchedLastTime?:number; }
export function normalizeFilterList(values?: string[]) { if (!Array.isArray(values)) return []; return [...new Set(values.map((v)=>(v??'').trim().toLowerCase()).filter(Boolean))].slice(0,50); }
export function buildPairKey(memberIds: string[]) {
 return memberIds.map((id)=>id.toString()).sort().join('_');
}
export class LastFilterPresetService {
 async getLast(userId:string, mode:'solo'|'paired') {
  const scope = await this.scope(userId, mode);
  return LastFilterPresetModel.findOne(scope).lean();
 }
 async hasLegacyPairedPreset(userId:string) {
  const scope = await this.scope(userId, 'paired');
  return Boolean(await LastFilterPresetModel.exists({ mode: 'paired', userId: null, pairKey: scope.pairKey }));
 }
 async saveLast(userId:string, payload:LastFilterPayload) { const scope = await this.scope(userId, payload.mode); const update = { ...scope, dishRegisters: normalizeFilterList(payload.dishRegisters), includeCustomDishesFirst: payload.includeCustomDishesFirst === true, cuisines: normalizeFilterList(payload.cuisines), moods: normalizeFilterList(payload.moods), diet: normalizeFilterList(payload.diet), exclusions: normalizeFilterList(payload.exclusions), matchedLastTime: Math.max(0, Math.min(10000, Number(payload.matchedLastTime ?? 0) || 0)), usedAt: new Date() }; try { return await LastFilterPresetModel.findOneAndUpdate(scope, {$set:update}, {upsert:true,new:true,setDefaultsOnInsert:true}).lean(); } catch (error) { if (isDuplicateKeyError(error) && payload.mode === 'paired') console.warn('[LastFilterPreset] duplicate while saving paired preset; run npm run fix:filter-preset-indexes to drop the legacy mode+pairKey unique index.'); throw error; } }
 private async scope(userId:string, mode:'solo'|'paired') { if (mode === 'solo') return { mode, userId: new Types.ObjectId(userId), pairKey: null }; const session = await CoupleSessionModel.findOne({members:new Types.ObjectId(userId), status:'active'}).sort({updatedAt:-1,createdAt:-1}).lean(); if (!session || session.members.length < 2) throw new AppError('No active paired session',404,'NO_ACTIVE_SESSION'); return { mode, userId: new Types.ObjectId(userId), pairKey: buildPairKey(session.members.map((m)=>m.toString())) }; }
}

function isDuplicateKeyError(error: unknown) {
 return typeof error === 'object' && error !== null && 'code' in error && (error as { code?: number }).code === 11000;
}
