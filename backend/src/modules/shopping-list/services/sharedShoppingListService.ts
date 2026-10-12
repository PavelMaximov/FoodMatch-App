import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionRecord } from '../../../domain/repositories/types';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { getPostgresPool, queryPostgres } from '../../../shared/db/postgresClient';
import { entitlementService } from '../../entitlements/services/entitlementService';

type Query = typeof queryPostgres;
type Transaction = <T>(task: (query: Query) => Promise<T>) => Promise<T>;
interface Dependencies {
  query: Query;
  transaction: Transaction;
  findActivePair: (userId: string) => Promise<CoupleSessionRecord | null>;
  canPairUseFeature: typeof entitlementService.canPairUseFeature;
}

async function transaction<T>(task: (query: Query) => Promise<T>): Promise<T> {
  const client = await getPostgresPool().connect();
  try {
    await client.query('begin');
    const result = await task((text, values = []) => client.query(text, [...values]));
    await client.query('commit');
    return result;
  } catch (error) {
    await client.query('rollback');
    throw error;
  } finally {
    client.release();
  }
}

const columns = 'id,name,normalized_name,quantity,measure,checked,sort_order,created_at,updated_at';
export class SharedShoppingListService {
  private readonly dependencies: Dependencies;
  constructor(dependencies: Partial<Dependencies> = {}) {
    this.dependencies = {
      query: queryPostgres, transaction,
      findActivePair: (userId) => domainRepositories.coupleSessions.findActiveForUser(userId),
      canPairUseFeature: (session, feature) => entitlementService.canPairUseFeature(session, feature),
      ...dependencies,
    };
  }

  private async read(sessionId: string, query = this.dependencies.query) {
    const result = await query(`select ${columns} from shared_shopping_list_items where couple_session_id=$1 order by sort_order,created_at,id`, [sessionId]);
    return { sessionId, items: result.rows };
  }

  async list(userId: string) {
    return this.read((await this.session(userId)).id);
  }

  // All writers lock the parent session so concurrent adds/removes cannot change
  // the complete list while reorder validates and assigns its order.
  private async mutate(userId: string, task: (sessionId: string, query: Query) => Promise<void>) {
    const session = await this.session(userId);
    return this.dependencies.transaction(async (query) => {
      const active = await query("select id from couple_sessions where id=$1 and status='active' and $2=any(member_ids) for update", [session.id, userId]);
      if (!active.rowCount) throw new AppError('An active pair is required.', 404, 'PAIR_SESSION_INACTIVE');
      await task(session.id, query);
      return this.read(session.id, query);
    });
  }

  async add(userId: string, input: { name?: unknown; quantity?: unknown; measure?: unknown }) {
    const name = String(input.name ?? '').trim();
    if (!name) throw new AppError('Item name is required.', 400, 'SHOPPING_LIST_ITEM_NAME_REQUIRED');
    return this.mutate(userId, async (sessionId, query) => {
      await query(`insert into shared_shopping_list_items(couple_session_id,created_by,name,normalized_name,quantity,measure,sort_order)
        values($1,$2,$3,$4,$5,$6,(select coalesce(max(sort_order),-1)+1 from shared_shopping_list_items where couple_session_id=$1))
        on conflict(couple_session_id,normalized_name) do update set
        quantity=coalesce(shared_shopping_list_items.quantity,excluded.quantity),
        measure=coalesce(shared_shopping_list_items.measure,excluded.measure),updated_at=now()`,
      [sessionId, userId, name, name.toLowerCase(), clean(input.quantity), clean(input.measure)]);
    });
  }

  async update(userId: string, id: string, input: { checked?: unknown }) {
    return this.mutate(userId, async (sessionId, query) => {
      const result = await query('update shared_shopping_list_items set checked=coalesce($3,checked),updated_at=now() where id=$1 and couple_session_id=$2 returning id',
        [id, sessionId, typeof input.checked === 'boolean' ? input.checked : null]);
      if (!result.rowCount) throw new AppError('Shopping-list item not found.', 404, 'SHOPPING_LIST_ITEM_NOT_FOUND');
    });
  }

  async remove(userId: string, id: string) {
    return this.mutate(userId, async (sessionId, query) => {
      const result = await query('delete from shared_shopping_list_items where id=$1 and couple_session_id=$2', [id, sessionId]);
      if (!result.rowCount) throw new AppError('Shopping-list item not found.', 404, 'SHOPPING_LIST_ITEM_NOT_FOUND');
    });
  }

  async reorder(userId: string, itemIds: unknown) {
    return this.mutate(userId, async (sessionId, query) => {
      const current = await query<{ id: string }>('select id from shared_shopping_list_items where couple_session_id=$1 for update', [sessionId]);
      const ids = new Set(current.rows.map((item) => item.id));
      if (!Array.isArray(itemIds) || itemIds.length !== ids.size ||
          new Set(itemIds).size !== itemIds.length || itemIds.some((id) => typeof id !== 'string' || !ids.has(id))) {
        throw new AppError('Reorder must contain every current item exactly once.', 409, 'SHOPPING_LIST_REORDER_SCOPE_MISMATCH');
      }
      await query(`update shared_shopping_list_items as item set sort_order=ordered.position-1,updated_at=now()
        from unnest($2::uuid[]) with ordinality as ordered(id,position)
        where item.couple_session_id=$1 and item.id=ordered.id`, [sessionId, itemIds]);
    });
  }

  private async session(userId: string) {
    const session = await this.dependencies.findActivePair(userId);
    if (!session || session.status !== 'active' || !session.memberIds.includes(userId)) {
      throw new AppError('An active pair is required.', 404, 'PAIR_SESSION_INACTIVE');
    }
    if (!await this.dependencies.canPairUseFeature(session, 'shared_shopping_list')) {
      throw new AppError('FoodMatch Premium is required for shopping lists.', 403, 'PREMIUM_SHOPPING_LIST_REQUIRED', { feature: 'shopping_list' });
    }
    return session;
  }
}
function clean(value: unknown) { return String(value ?? '').trim() || null; }
