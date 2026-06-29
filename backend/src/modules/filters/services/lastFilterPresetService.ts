import { Types } from 'mongoose';
import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionModel } from '../../couples/models/CoupleSession';
import { LastFilterPresetModel } from '../models/LastFilterPreset';

export interface LastFilterPayload { mode:'solo'|'paired'; cuisines?:string[]; moods?:string[]; diet?:string[]; exclusions?:string[]; matchedLastTime?:number; }
export function normalizeFilterList(values?: string[]) { if (!Array.isArray(values)) return []; return [...new Set(values.map((v)=>(v??'').trim().toLowerCase()).filter(Boolean))].slice(0,50); }
export class LastFilterPresetService {
 async getLast(userId:string, mode:'solo'|'paired') { const scope = await this.scope(userId, mode); return LastFilterPresetModel.findOne(scope).lean(); }
 async saveLast(userId:string, payload:LastFilterPayload) { const scope = await this.scope(userId, payload.mode); const update = { ...scope, cuisines: normalizeFilterList(payload.cuisines), moods: normalizeFilterList(payload.moods), diet: normalizeFilterList(payload.diet), exclusions: normalizeFilterList(payload.exclusions), matchedLastTime: Math.max(0, Math.min(10000, Number(payload.matchedLastTime ?? 0) || 0)), usedAt: new Date() }; return LastFilterPresetModel.findOneAndUpdate(scope, {$set:update}, {upsert:true,new:true,setDefaultsOnInsert:true}).lean(); }
 private async scope(userId:string, mode:'solo'|'paired') { if (mode === 'solo') return { mode, userId: new Types.ObjectId(userId), pairKey: null }; const session = await CoupleSessionModel.findOne({members:new Types.ObjectId(userId), status:'active'}).lean(); if (!session || session.members.length < 2) throw new AppError('No active paired session',404,'NO_ACTIVE_SESSION'); const ids = session.members.map((m)=>m.toString()).sort(); return { mode, pairKey: `${ids[0]}_${ids[1]}` }; }
}
