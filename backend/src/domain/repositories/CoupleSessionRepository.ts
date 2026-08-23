import { CoupleSessionRecord, JsonMap } from './types';
export interface PairFilterStateRecord { userId: string; filters: JsonMap; confirmed: boolean; confirmedAt: Date | null; }
export interface CoupleSessionRepository {
 findActiveForUser(userId:string):Promise<CoupleSessionRecord|null>; findById(id:string):Promise<CoupleSessionRecord|null>; findByInviteCode(code:string):Promise<CoupleSessionRecord|null>;
 create(input:{inviteCode:string;createdBy:string;memberIds:string[]}):Promise<CoupleSessionRecord>;
 update(id:string,patch:Partial<Pick<CoupleSessionRecord,'status'|'memberIds'|'pairKey'|'preparedDeckDishIds'|'preparedDeckGeneration'|'preparedDeckFiltersHash'|'preparedDeckMeta'|'restartState'|'pairLifecycleState'|'closedAt'>>):Promise<CoupleSessionRecord|null>;
 delete(id:string):Promise<void>; listFilterStates(sessionId:string):Promise<PairFilterStateRecord[]>; upsertFilterState(sessionId:string,state:PairFilterStateRecord):Promise<void>; clearFilterStates(sessionId:string):Promise<void>;
}
