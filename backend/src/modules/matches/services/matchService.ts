import { AppError } from '../../../core/errors/AppError';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { loadMongoDishesInPostgresOrder } from '../../../shared/db/dishIdMapping';
import { getPostgresPool } from '../../../shared/db/postgresClient';
import { toDishDto } from '../../dishes/dto/dishDto';
import { requirePremiumFeature } from '../../entitlements/services/featureAccessService';
import { QueryResult, QueryResultRow } from 'pg';

type HistoryListRow = {
  session_id: string;
  started_at: Date;
  completed_at: Date | null;
  session_status: string;
  partner_name?: string | null;
  dish_count: number | string;
  preview_dish_ids: string[];
};

type HistoryDetailRow = HistoryListRow & { mode: 'solo' | 'pair'; dish_ids: string[] };
type HistoryQuery = <T extends QueryResultRow>(text:string,values?:readonly unknown[])=>Promise<QueryResult<T>>;

export class MatchService {
  constructor(private readonly dependencies:{query?:HistoryQuery;requireFeature?:typeof requirePremiumFeature;loadDishes?:typeof loadMongoDishesInPostgresOrder}={}){}
  private query<T extends Record<string,unknown>>(text:string,values:unknown[]){return (this.dependencies.query??getPostgresPool().query.bind(getPostgresPool()))<T>(text,values);}
  async listForCouple(coupleId: string) {
    const matches = await domainRepositories.matches.listForCouple(coupleId);
    const dishes = await loadMongoDishesInPostgresOrder(matches.map((match) => match.dishId));
    return matches.map((match, index) => ({
      id: match.id,
      coupleId: match.coupleSessionId,
      users: [],
      createdAt: match.createdAt,
      dish: toDishDto(dishes[index]),
    })).filter((match) => match.dish);
  }

  async historyForUser(userId: string) {
    await (this.dependencies.requireFeature??requirePremiumFeature)(userId, 'session_history', 'PREMIUM_SESSION_HISTORY_REQUIRED');
    const [soloRows, pairRows] = await Promise.all([
      this.query<HistoryListRow>(SOLO_HISTORY_LIST_SQL, [userId]),
      this.query<HistoryListRow>(PAIR_HISTORY_LIST_SQL, [userId]),
    ]);
    return {
      solo: await Promise.all(soloRows.rows.map((row) => this.listDto(row))),
      pair: await Promise.all(pairRows.rows.map((row) => this.listDto(row, row.partner_name))),
    };
  }

  async historySessionForUser(userId: string, sessionId: string) {
    await (this.dependencies.requireFeature??requirePremiumFeature)(userId, 'session_history', 'PREMIUM_SESSION_HISTORY_REQUIRED');
    const result = await this.query<HistoryDetailRow>(HISTORY_DETAIL_SQL, [userId, sessionId]);
    const row = result.rows[0];
    if (!row) throw new AppError('Historical session not found.', 404, 'SESSION_HISTORY_NOT_FOUND');
    const dishes = (await (this.dependencies.loadDishes??loadMongoDishesInPostgresOrder)(row.dish_ids)).map(toDishDto).filter(Boolean);
    return {
      sessionId: row.session_id,
      mode: row.mode,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      status: row.session_status,
      partnerName: row.partner_name ?? null,
      dishCount: Number(row.dish_count),
      previewDishes: dishes.slice(0, 3),
      dishes,
    };
  }

  private async listDto(row: HistoryListRow, partnerName?: string | null) {
    const previewDishes = (await (this.dependencies.loadDishes??loadMongoDishesInPostgresOrder)(row.preview_dish_ids)).map(toDishDto).filter(Boolean);
    return {
      sessionId: row.session_id,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      status: row.session_status,
      partnerName: partnerName ?? null,
      dishCount: Number(row.dish_count),
      previewDishes,
    };
  }
}

const SOLO_HISTORY_LIST_SQL = `
  select s.id session_id,s.created_at started_at,s.completed_at,s.status session_status,
         count(w.dish_id)::int dish_count,
         coalesce((array_agg(w.dish_id order by w.created_at desc) filter(where w.dish_id is not null))[1:3],'{}') preview_dish_ids
    from solo_swipe_sessions s
    left join swipes w on w.solo_session_id=s.id and w.user_id=$1 and w.mode='solo' and w.direction='like'
   where s.user_id=$1
   group by s.id
   order by coalesce(s.completed_at,s.updated_at) desc`;

const PAIR_HISTORY_LIST_SQL = `
  select c.id session_id,c.created_at started_at,c.closed_at completed_at,c.status session_status,
         partner.display_name partner_name,count(m.dish_id)::int dish_count,
         coalesce((array_agg(m.dish_id order by m.created_at desc) filter(where m.dish_id is not null))[1:3],'{}') preview_dish_ids
    from couple_sessions c
    left join matches m on m.couple_session_id=c.id and m.mode='paired'
    left join lateral(select p.display_name from profiles p where p.id=any(c.member_ids) and p.id<>$1 limit 1) partner on true
   where $1=any(c.member_ids)
   group by c.id,partner.display_name
   order by coalesce(c.closed_at,c.updated_at) desc`;

const HISTORY_DETAIL_SQL = `
  select * from (
    select s.id session_id,'solo'::text mode,s.created_at started_at,s.completed_at,s.status session_status,
           null::text partner_name,count(w.dish_id)::int dish_count,
           '{}'::uuid[] preview_dish_ids,
           coalesce(array_agg(w.dish_id order by w.created_at desc) filter(where w.dish_id is not null),'{}') dish_ids
      from solo_swipe_sessions s
      left join swipes w on w.solo_session_id=s.id and w.user_id=$1 and w.mode='solo' and w.direction='like'
     where s.id=$2 and s.user_id=$1 group by s.id
    union all
    select c.id session_id,'pair'::text mode,c.created_at started_at,c.closed_at completed_at,c.status session_status,
           partner.display_name partner_name,count(m.dish_id)::int dish_count,
           '{}'::uuid[] preview_dish_ids,
           coalesce(array_agg(m.dish_id order by m.created_at desc) filter(where m.dish_id is not null),'{}') dish_ids
      from couple_sessions c
      left join matches m on m.couple_session_id=c.id and m.mode='paired'
      left join lateral(select p.display_name from profiles p where p.id=any(c.member_ids) and p.id<>$1 limit 1) partner on true
     where c.id=$2 and $1=any(c.member_ids) group by c.id,partner.display_name
  ) owned_session limit 1`;
