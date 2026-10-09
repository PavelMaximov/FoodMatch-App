import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { loadMongoDishesInPostgresOrder } from '../../../shared/db/dishIdMapping';
import { toDishDto } from '../../dishes/dto/dishDto';
import { getPostgresPool } from '../../../shared/db/postgresClient';
import { AppError } from '../../../core/errors/AppError';
import { requirePremiumFeature } from '../../entitlements/services/featureAccessService';

type HistoryRow = {
  session_id: string;
  started_at: Date;
  completed_at: Date | null;
  session_status: string;
  partner_name?: string | null;
  dish_ids: string[];
};

export class MatchService {
  async listForCouple(coupleId:string){const matches=await domainRepositories.matches.listForCouple(coupleId);const dishes=await loadMongoDishesInPostgresOrder(matches.map(m=>m.dishId));return matches.map((m,i)=>({id:m.id,coupleId:m.coupleSessionId,users:[],createdAt:m.createdAt,dish:toDishDto(dishes[i])})).filter(x=>x.dish);}

  async historyForUser(userId: string) {
    await requirePremiumFeature(userId,'session_history','PREMIUM_SESSION_HISTORY_REQUIRED');
    const [soloRows, pairRows] = await Promise.all([
      getPostgresPool().query<HistoryRow>(
        `select s.id session_id, s.created_at started_at, s.status session_status,
                s.completed_at, coalesce(array_agg(w.dish_id order by w.created_at desc) filter(where w.dish_id is not null),'{}') dish_ids
           from solo_swipe_sessions s
           left join swipes w on w.solo_session_id=s.id and w.user_id=$1
             and w.mode='solo' and w.direction='like'
          where s.user_id=$1
          group by s.id, s.status
          order by coalesce(s.completed_at,s.updated_at) desc`,
        [userId],
      ),
      getPostgresPool().query<HistoryRow>(
        `select c.id session_id, c.created_at started_at, c.status session_status,
                c.closed_at completed_at, partner.display_name partner_name,
                coalesce(array_agg(m.dish_id order by m.created_at desc) filter(where m.dish_id is not null),'{}') dish_ids
           from couple_sessions c
           left join matches m on m.couple_session_id=c.id and m.mode='paired'
           left join lateral (
             select p.display_name from profiles p
              where p.id=any(c.member_ids) and p.id<>$1 limit 1
           ) partner on true
          where $1=any(c.member_ids)
          group by c.id, c.status, partner.display_name
          order by coalesce(c.closed_at,c.updated_at) desc`,
        [userId],
      ),
    ]);
    return {
      solo: await Promise.all(soloRows.rows.map((row) => this.historyDto(row))),
      pair: await Promise.all(pairRows.rows.map((row) => this.historyDto(row, row.partner_name))),
    };
  }

  async historySessionForUser(userId:string,sessionId:string){
    const history=await this.historyForUser(userId);
    const solo=history.solo.find(session=>session.sessionId===sessionId);
    if(solo)return{...solo,mode:'solo'};
    const pair=history.pair.find(session=>session.sessionId===sessionId);
    if(pair)return{...pair,mode:'pair'};
    throw new AppError('Historical session not found.',404,'SESSION_HISTORY_NOT_FOUND');
  }

  private async historyDto(row: HistoryRow, partnerName?: string | null) {
    const dishes = (await loadMongoDishesInPostgresOrder(row.dish_ids))
      .map(toDishDto)
      .filter(Boolean);
    return {
      sessionId: row.session_id,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      status: row.session_status,
      partnerName: partnerName ?? null,
      dishCount: dishes.length,
      previewDishes: dishes.slice(0, 3),
      dishes,
    };
  }
}
