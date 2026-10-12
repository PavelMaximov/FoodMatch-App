import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { loadMongoDishesInPostgresOrder } from '../../../shared/db/dishIdMapping';
import { toDishDto } from '../../dishes/dto/dishDto';
import { queryPostgres } from '../../../shared/db/postgresClient';
import { AppError } from '../../../core/errors/AppError';
import { requirePremiumFeature } from '../../entitlements/services/featureAccessService';

type HistoryRow = {
  session_id: string; started_at: Date; completed_at: Date | null;
  session_status: string; partner_name?: string | null;
  dish_count: number | string; dish_ids: string[];
};
interface Dependencies {
  query: typeof queryPostgres;
  hydrateDishes: (ids: string[]) => Promise<ReturnType<typeof toDishDto>[]>;
  requireHistoryAccess: (userId: string) => Promise<void>;
}

// Count every result, but select only preview IDs for list hydration. Detail
// queries preserve ownership predicates and load IDs for one requested session.
function soloQuery(detail: boolean) {
  return `select s.id session_id,s.created_at started_at,s.completed_at,s.status session_status,
    (select count(*) from swipes w where w.solo_session_id=s.id and w.user_id=$1 and w.mode='solo' and w.direction='like') dish_count,
    array(select w.dish_id from swipes w where w.solo_session_id=s.id and w.user_id=$1 and w.mode='solo' and w.direction='like'
      order by w.created_at desc,w.id ${detail ? '' : 'limit 3'}) dish_ids
    from solo_swipe_sessions s where s.user_id=$1 ${detail ? 'and s.id=$2' : ''}
    order by coalesce(s.completed_at,s.updated_at) desc ${detail ? 'limit 1' : ''}`;
}
function pairQuery(detail: boolean) {
  return `select c.id session_id,c.created_at started_at,c.closed_at completed_at,c.status session_status,partner.display_name partner_name,
    (select count(*) from matches m where m.couple_session_id=c.id and m.mode='paired') dish_count,
    array(select m.dish_id from matches m where m.couple_session_id=c.id and m.mode='paired'
      order by m.created_at desc,m.id ${detail ? '' : 'limit 3'}) dish_ids
    from couple_sessions c left join lateral (
      select p.display_name from profiles p where p.id=any(c.member_ids) and p.id<>$1 limit 1
    ) partner on true where $1=any(c.member_ids) ${detail ? 'and c.id=$2' : ''}
    order by coalesce(c.closed_at,c.updated_at) desc ${detail ? 'limit 1' : ''}`;
}

export class MatchService {
  private readonly dependencies: Dependencies;
  constructor(dependencies: Partial<Dependencies> = {}) {
    this.dependencies = {
      query: queryPostgres,
      hydrateDishes: async (ids) => (await loadMongoDishesInPostgresOrder(ids)).map(toDishDto).filter(Boolean),
      requireHistoryAccess: (userId) => requirePremiumFeature(userId, 'session_history', 'PREMIUM_SESSION_HISTORY_REQUIRED'),
      ...dependencies,
    };
  }
  async listForCouple(coupleId:string){const matches=await domainRepositories.matches.listForCouple(coupleId);const dishes=await loadMongoDishesInPostgresOrder(matches.map(m=>m.dishId));return matches.map((m,i)=>({id:m.id,coupleId:m.coupleSessionId,users:[],createdAt:m.createdAt,dish:toDishDto(dishes[i])})).filter(x=>x.dish);}

  async historyForUser(userId: string) {
    await this.dependencies.requireHistoryAccess(userId);
    const [soloRows, pairRows] = await Promise.all([
      this.dependencies.query<HistoryRow>(soloQuery(false), [userId]),
      this.dependencies.query<HistoryRow>(pairQuery(false), [userId]),
    ]);
    const previewIds = [...new Set([...soloRows.rows, ...pairRows.rows].flatMap((row) => row.dish_ids.slice(0, 3)))];
    const dishes = previewIds.length ? await this.dependencies.hydrateDishes(previewIds) : [];
    const byId = new Map(dishes.filter(Boolean).map((dish) => [String(dish!.id), dish]));
    const dto = (row: HistoryRow) => ({
      ...this.metadata(row), previewDishes: row.dish_ids.slice(0, 3).map((id) => byId.get(id)).filter(Boolean),
    });
    return { solo: soloRows.rows.map(dto), pair: pairRows.rows.map(dto) };
  }

  async historySessionForUser(userId: string, sessionId: string) {
    await this.dependencies.requireHistoryAccess(userId);
    const solo = await this.dependencies.query<HistoryRow>(soloQuery(true), [userId, sessionId]);
    let row = solo.rows[0];
    let mode = 'solo';
    if (!row) {
      const pair = await this.dependencies.query<HistoryRow>(pairQuery(true), [userId, sessionId]);
      row = pair.rows[0];
      mode = 'pair';
    }
    if (!row) throw new AppError('Historical session not found.', 404, 'SESSION_HISTORY_NOT_FOUND');
    const dishes = row.dish_ids.length ? await this.dependencies.hydrateDishes(row.dish_ids) : [];
    return { ...this.metadata(row), mode, previewDishes: dishes.slice(0, 3), dishes };
  }
  private metadata(row: HistoryRow) {
    return {
      sessionId: row.session_id, startedAt: row.started_at, completedAt: row.completed_at,
      status: row.session_status, partnerName: row.partner_name ?? null, dishCount: Number(row.dish_count),
    };
  }
}
