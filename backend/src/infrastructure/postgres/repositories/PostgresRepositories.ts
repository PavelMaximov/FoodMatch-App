import { randomUUID } from 'crypto';
import { PoolClient, QueryResultRow } from 'pg';
import { CoupleInvitationRepository } from '../../../domain/repositories/CoupleInvitationRepository';
import { CoupleSessionRepository, PairFilterStateRecord } from '../../../domain/repositories/CoupleSessionRepository';
import { FilterPresetRepository } from '../../../domain/repositories/FilterPresetRepository';
import { MatchRepository } from '../../../domain/repositories/MatchRepository';
import { SoloSessionRepository } from '../../../domain/repositories/SoloSessionRepository';
import { SwipeRepository } from '../../../domain/repositories/SwipeRepository';
import { CoupleSessionRecord, FilterPresetRecord, InvitationRecord, JsonMap, MatchRecord, Mode, SoloSessionRecord, SwipeRecord } from '../../../domain/repositories/types';
import { getPostgresPool } from '../../../shared/db/postgresClient';

const camel = (row: QueryResultRow): any => Object.fromEntries(Object.entries(row).map(([key,value]) => [key.replace(/_([a-z])/g,(_,c)=>c.toUpperCase()),value]));
const one = <T>(rows: QueryResultRow[]): T|null => rows[0] ? camel(rows[0]) as T : null;

export class PostgresSoloSessionRepository implements SoloSessionRepository {
 async findByIdForUser(id:string,userId:string){ return one<SoloSessionRecord>((await getPostgresPool().query('select * from solo_swipe_sessions where id=$1 and user_id=$2',[id,userId])).rows); }
 async findActive(userId:string){ return one<SoloSessionRecord>((await getPostgresPool().query("select * from solo_swipe_sessions where user_id=$1 and status='active' order by updated_at desc limit 1",[userId])).rows); }
 async findResumable(userId:string){ return one<SoloSessionRecord>((await getPostgresPool().query("select * from solo_swipe_sessions where user_id=$1 and status in ('active','completed') order by updated_at desc limit 1",[userId])).rows); }
 async create(i:{userId:string;deckDishIds:string[];filters:JsonMap;filtersHash?:string;algorithm?:string;meta?:JsonMap}){ return one<SoloSessionRecord>((await getPostgresPool().query('insert into solo_swipe_sessions(user_id,status,deck_dish_ids,filters,filters_hash,algorithm,meta) values($1,\'active\',$2,$3,$4,$5,$6) returning *',[i.userId,i.deckDishIds,i.filters,i.filtersHash??null,i.algorithm??null,i.meta??{}])).rows)!; }
 async replaceActive(i:{userId:string;deckDishIds:string[];filters:JsonMap;filtersHash?:string;algorithm?:string;meta?:JsonMap}){const client=await getPostgresPool().connect();try{await client.query('begin');await client.query('select pg_advisory_xact_lock(hashtext($1))',[`solo:${i.userId}`]);await client.query("update solo_swipe_sessions set status='closed',updated_at=now() where user_id=$1 and status='active'",[i.userId]);const created=one<SoloSessionRecord>((await client.query('insert into solo_swipe_sessions(user_id,status,deck_dish_ids,filters,filters_hash,algorithm,meta) values($1,\'active\',$2,$3,$4,$5,$6) returning *',[i.userId,i.deckDishIds,i.filters,i.filtersHash??null,i.algorithm??null,i.meta??{}])).rows)!;await client.query('commit');return created;}catch(error){await client.query('rollback');throw error;}finally{client.release();}}
 async update(id:string,userId:string,p:any){ const keys:{[key:string]:string}={status:'status',deckDishIds:'deck_dish_ids',currentIndex:'current_index',filters:'filters',filtersHash:'filters_hash',algorithm:'algorithm',meta:'meta',completedAt:'completed_at'}; const entries=Object.entries(p).filter(([k])=>keys[k]); if(!entries.length)return this.findByIdForUser(id,userId); const values=entries.map(([,v])=>v); const set=entries.map(([k],n)=>`${keys[k]}=$${n+3}`).join(','); return one<SoloSessionRecord>((await getPostgresPool().query(`update solo_swipe_sessions set ${set},updated_at=now() where id=$1 and user_id=$2 returning *`,[id,userId,...values])).rows); }
 async setStatusForActive(userId:string,status:any){ return one<SoloSessionRecord>((await getPostgresPool().query("update solo_swipe_sessions set status=$2,completed_at=case when $2='completed' then now() else completed_at end,updated_at=now() where id=(select id from solo_swipe_sessions where user_id=$1 and status='active' order by updated_at desc limit 1) returning *",[userId,status])).rows); }
}

export class PostgresCoupleSessionRepository implements CoupleSessionRepository {
 async findActiveForUser(u:string){return one<CoupleSessionRecord>((await getPostgresPool().query("select * from couple_sessions where $1=any(member_ids) and status='active' order by updated_at desc limit 1",[u])).rows);}
 async findById(id:string){return one<CoupleSessionRecord>((await getPostgresPool().query('select * from couple_sessions where id=$1',[id])).rows);}
 async findByInviteCode(c:string){return one<CoupleSessionRecord>((await getPostgresPool().query('select * from couple_sessions where invite_code=$1',[c])).rows);}
 async create(i:{inviteCode:string;createdBy:string;memberIds:string[]}){return one<CoupleSessionRecord>((await getPostgresPool().query("insert into couple_sessions(invite_code,status,created_by,member_ids) values($1,'active',$2,$3) returning *",[i.inviteCode,i.createdBy,i.memberIds])).rows)!;}
 async update(id:string,p:any){const m:any={status:'status',memberIds:'member_ids',pairKey:'pair_key',preparedDeckDishIds:'prepared_deck_dish_ids',preparedDeckGeneration:'prepared_deck_generation',preparedDeckFiltersHash:'prepared_deck_filters_hash',preparedDeckMeta:'prepared_deck_meta',restartState:'restart_state',pairLifecycleState:'pair_lifecycle_state',closedAt:'closed_at'};const e=Object.entries(p).filter(([k])=>m[k]);if(!e.length)return this.findById(id);return one<CoupleSessionRecord>((await getPostgresPool().query(`update couple_sessions set ${e.map(([k],n)=>`${m[k]}=$${n+2}`).join(',')},updated_at=now() where id=$1 returning *`,[id,...e.map(([,v])=>v)])).rows);}
 async delete(id:string){await getPostgresPool().query('delete from couple_sessions where id=$1',[id]);}
 async listFilterStates(id:string){return (await getPostgresPool().query('select user_id,filters,confirmed,confirmed_at from pair_filter_states where couple_session_id=$1',[id])).rows.map(camel) as PairFilterStateRecord[];}
 async upsertFilterState(id:string,s:PairFilterStateRecord){await getPostgresPool().query('insert into pair_filter_states(couple_session_id,user_id,filters,confirmed,confirmed_at) values($1,$2,$3,$4,$5) on conflict(couple_session_id,user_id) do update set filters=excluded.filters,confirmed=excluded.confirmed,confirmed_at=excluded.confirmed_at,updated_at=now()',[id,s.userId,s.filters,s.confirmed,s.confirmedAt]);}
 async clearFilterStates(id:string){await getPostgresPool().query('delete from pair_filter_states where couple_session_id=$1',[id]);}
}

export class PostgresSwipeRepository implements SwipeRepository {
 async createOnce(i:any){const sid=i.mode==='solo'?i.soloSessionId:i.coupleSessionId;const column=i.mode==='solo'?'solo_session_id':'couple_session_id';const client=await getPostgresPool().connect();try{await client.query('begin');const inserted=await client.query(`insert into swipes(user_id,dish_id,mode,direction,${column}) values($1,$2,$3,$4,$5) on conflict do nothing returning *`,[i.userId,i.dishId,i.mode,i.direction,sid]);const row=inserted.rows[0]??(await client.query(`select * from swipes where user_id=$1 and dish_id=$2 and ${column}=$3`,[i.userId,i.dishId,sid])).rows[0];await client.query('commit');return{swipe:camel(row) as SwipeRecord,created:Boolean(inserted.rows[0])};}catch(e){await client.query('rollback');throw e;}finally{client.release();}}
 async listForUserSession(u:string,s:string,m:Mode){const col=m==='solo'?'solo_session_id':'couple_session_id';return(await getPostgresPool().query(`select * from swipes where user_id=$1 and ${col}=$2 order by created_at desc`,[u,s])).rows.map(camel) as SwipeRecord[];}
 async countLikes(s:string,d:string,m:Mode){const col=m==='solo'?'solo_session_id':'couple_session_id';return Number((await getPostgresPool().query(`select count(distinct user_id) n from swipes where ${col}=$1 and dish_id=$2 and direction='like'`,[s,d])).rows[0].n);}
 async deleteLatest(u:string,s:string,m:Mode){const col=m==='solo'?'solo_session_id':'couple_session_id';return one<SwipeRecord>((await getPostgresPool().query(`delete from swipes where id=(select id from swipes where user_id=$1 and ${col}=$2 order by created_at desc limit 1) returning *`,[u,s])).rows);}
 async deleteForSession(s:string,m:Mode){await getPostgresPool().query(`delete from swipes where ${m==='solo'?'solo_session_id':'couple_session_id'}=$1`,[s]);}
}

export class PostgresMatchRepository implements MatchRepository {
 async createOnce(i:any){const col=i.mode==='solo'?'user_id':'couple_session_id',owner=i.mode==='solo'?i.userId:i.coupleSessionId;const inserted=await getPostgresPool().query(`insert into matches(dish_id,mode,${col}) values($1,$2,$3) on conflict do nothing returning *`,[i.dishId,i.mode,owner]);const row=inserted.rows[0]??(await getPostgresPool().query(`select * from matches where dish_id=$1 and mode=$2 and ${col}=$3`,[i.dishId,i.mode,owner])).rows[0];return{match:camel(row) as MatchRecord,created:Boolean(inserted.rows[0])};}
 async listForUser(u:string,m?:Mode){return(await getPostgresPool().query('select m.* from matches m left join couple_sessions c on c.id=m.couple_session_id where (m.user_id=$1 or $1=any(c.member_ids)) and ($2::text is null or m.mode=$2) order by m.created_at desc',[u,m??null])).rows.map(camel) as MatchRecord[];}
 async listForCouple(c:string){return(await getPostgresPool().query('select * from matches where couple_session_id=$1 order by created_at desc',[c])).rows.map(camel) as MatchRecord[];}
 async deleteSolo(u:string,d:string){await getPostgresPool().query("delete from matches where mode='solo' and user_id=$1 and dish_id=$2",[u,d]);}
 async deleteForCouple(c:string){await getPostgresPool().query('delete from matches where couple_session_id=$1',[c]);}
}

export class PostgresCoupleInvitationRepository implements CoupleInvitationRepository {
 async createOrRefresh(i:any){return one<InvitationRecord>((await getPostgresPool().query(`insert into couple_invitations(from_user_id,to_user_id,pair_key,previous_couple_session_id,new_couple_session_id,previous_filter_preset_id,status,matched_last_time,mutual_match_count,expires_at) values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) on conflict(from_user_id,to_user_id,pair_key) where status='pending' do update set expires_at=excluded.expires_at,updated_at=now(),new_couple_session_id=excluded.new_couple_session_id returning *`,[i.fromUserId,i.toUserId,i.pairKey,i.previousCoupleSessionId,i.newCoupleSessionId,i.previousFilterPresetId,i.status,i.matchedLastTime,i.mutualMatchCount,i.expiresAt])).rows)!;}
 async findForParticipant(id:string,u:string){return one<InvitationRecord>((await getPostgresPool().query('select * from couple_invitations where id=$1 and (from_user_id=$2 or to_user_id=$2)',[id,u])).rows);}
 async listPendingIncoming(u:string,now=new Date()){return(await getPostgresPool().query("select i.* from couple_invitations i join couple_sessions c on c.id=i.new_couple_session_id and c.status='active' where i.to_user_id=$1 and i.status='pending' and i.mode='paired' and i.expires_at>$2 order by i.updated_at desc limit 20",[u,now])).rows.map(camel) as InvitationRecord[];}
 async setStatus(id:string,s:any){return one<InvitationRecord>((await getPostgresPool().query('update couple_invitations set status=$2,updated_at=now() where id=$1 returning *',[id,s])).rows);}
 async expirePending(now=new Date()){return(await getPostgresPool().query("update couple_invitations set status='expired',updated_at=now() where status='pending' and expires_at<=$1",[now])).rowCount??0;}
}

export class PostgresFilterPresetRepository implements FilterPresetRepository {
 async findLast(u:string,m:Mode,p:string|null=null){return one<FilterPresetRecord>((await getPostgresPool().query('select * from filter_presets where user_id=$1 and mode=$2 and pair_key is not distinct from $3 order by used_at desc nulls last,updated_at desc limit 1',[u,m,p])).rows);}
 async upsert(i:any){const existing=await this.findLast(i.userId,i.mode,i.pairKey??null);if(existing)return one<FilterPresetRecord>((await getPostgresPool().query('update filter_presets set filters=$2,is_meaningful=$3,used_at=$4,updated_at=now() where id=$1 returning *',[existing.id,i.filters,i.isMeaningful,i.usedAt??new Date()])).rows)!;return one<FilterPresetRecord>((await getPostgresPool().query('insert into filter_presets(user_id,mode,pair_key,filters,is_meaningful,used_at) values($1,$2,$3,$4,$5,$6) returning *',[i.userId,i.mode,i.pairKey??null,i.filters,i.isMeaningful,i.usedAt??new Date()])).rows)!;}
}
