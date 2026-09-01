import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { loadMongoDishesInPostgresOrder } from '../../../shared/db/dishIdMapping';
import { toDishDto } from '../../dishes/dto/dishDto';
import { getPostgresPool } from '../../../shared/db/postgresClient';

type HistoryRow = {
  session_id: string;
  started_at: Date;
  completed_at: Date | null;
  partner_name?: string | null;
  dish_ids: string[];
};

export class MatchService {
  async listForCouple(coupleId:string){const matches=await domainRepositories.matches.listForCouple(coupleId);const dishes=await loadMongoDishesInPostgresOrder(matches.map(m=>m.dishId));return matches.map((m,i)=>({id:m.id,coupleId:m.coupleSessionId,users:[],createdAt:m.createdAt,dish:toDishDto(dishes[i])})).filter(x=>x.dish);}

  async historyForUser(userId: string) {
    const [soloRows, pairRows] = await Promise.all([
      getPostgresPool().query<HistoryRow>(
        `select s.id session_id, s.created_at started_at,
                s.completed_at, array_agg(w.dish_id order by w.created_at desc) dish_ids
           from solo_swipe_sessions s
           join swipes w on w.solo_session_id=s.id and w.user_id=$1
             and w.mode='solo' and w.direction='like'
          where s.user_id=$1
          group by s.id
          order by coalesce(s.completed_at,s.updated_at) desc`,
        [userId],
      ),
      getPostgresPool().query<HistoryRow>(
        `select c.id session_id, c.created_at started_at,
                c.closed_at completed_at, partner.display_name partner_name,
                array_agg(m.dish_id order by m.created_at desc) dish_ids
           from couple_sessions c
           join matches m on m.couple_session_id=c.id and m.mode='paired'
           left join lateral (
             select p.display_name from profiles p
              where p.id=any(c.member_ids) and p.id<>$1 limit 1
           ) partner on true
          where $1=any(c.member_ids)
          group by c.id, partner.display_name
          order by coalesce(c.closed_at,c.updated_at) desc`,
        [userId],
      ),
    ]);
    return {
      solo: await Promise.all(soloRows.rows.map((row) => this.historyDto(row))),
      pair: await Promise.all(pairRows.rows.map((row) => this.historyDto(row, row.partner_name))),
    };
  }

  private async historyDto(row: HistoryRow, partnerName?: string | null) {
    const dishes = (await loadMongoDishesInPostgresOrder(row.dish_ids))
      .map(toDishDto)
      .filter(Boolean);
    return {
      sessionId: row.session_id,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      partnerName: partnerName ?? null,
      dishCount: dishes.length,
      previewDishes: dishes.slice(0, 3),
      dishes,
    };
  }
}
