import { MatchRecord, Mode } from './types';
export interface MatchRepository { createOnce(input:{dishId:string;mode:Mode;userId?:string;coupleSessionId?:string}):Promise<{match:MatchRecord;created:boolean}>; listForUser(userId:string,mode?:Mode):Promise<MatchRecord[]>; listForCouple(coupleSessionId:string):Promise<MatchRecord[]>; deleteForCouple(coupleSessionId:string):Promise<void>; }
