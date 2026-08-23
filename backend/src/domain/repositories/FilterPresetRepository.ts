import { FilterPresetRecord, JsonMap, Mode } from './types';
export interface FilterPresetRepository { findLast(userId:string,mode:Mode,pairKey?:string|null):Promise<FilterPresetRecord|null>; upsert(input:{userId:string;mode:Mode;pairKey?:string|null;filters:JsonMap;isMeaningful:boolean;usedAt?:Date}):Promise<FilterPresetRecord>; }
