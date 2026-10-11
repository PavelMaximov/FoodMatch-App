import { AppError } from '../../../core/errors/AppError';
import { CoupleSessionRecord } from '../../../domain/repositories/types';
import { domainRepositories } from '../../../infrastructure/repositories/domainRepositories';
import { getPostgresPool, queryPostgres } from '../../../shared/db/postgresClient';
import { entitlementService } from '../../entitlements/services/entitlementService';

type ItemInput = { name?: unknown; quantity?: unknown; measure?: unknown };

export class SharedShoppingListService {
  constructor(private readonly dependencies:{findActive?:(userId:string)=>Promise<CoupleSessionRecord|null>;canPair?:(session:CoupleSessionRecord)=>Promise<boolean>;query?:typeof queryPostgres;connect?:()=>Promise<any>}={}){}
  async list(userId: string) {
    const session = await this.requireSession(userId);
    return this.listForSession(session.id);
  }

  async add(userId: string, input: ItemInput) {
    const session = await this.requireSession(userId);
    const name = String(input.name ?? '').trim();
    if (!name) throw new AppError('Item name is required.', 400, 'SHOPPING_LIST_ITEM_NAME_REQUIRED');
    await this.query(
      `insert into shared_shopping_list_items
        (couple_session_id,created_by,name,normalized_name,quantity,measure,sort_order)
       values($1,$2,$3,$4,$5,$6,(select count(*) from shared_shopping_list_items where couple_session_id=$1))
       on conflict(couple_session_id,normalized_name) do update set
         quantity=coalesce(shared_shopping_list_items.quantity,excluded.quantity),
         measure=coalesce(shared_shopping_list_items.measure,excluded.measure),updated_at=now()`,
      [session.id, userId, name, name.toLowerCase(), clean(input.quantity), clean(input.measure)],
    );
    return this.listForSession(session.id);
  }

  async update(userId: string, id: string, input: { checked?: unknown }) {
    const session = await this.requireSession(userId);
    const result = await this.query(
      'update shared_shopping_list_items set checked=coalesce($3,checked),updated_at=now() where id=$1 and couple_session_id=$2 returning id',
      [id, session.id, typeof input.checked === 'boolean' ? input.checked : null],
    );
    if (!result.rowCount) throw itemNotFound();
    return this.listForSession(session.id);
  }

  async remove(userId: string, id: string) {
    const session = await this.requireSession(userId);
    const result = await this.query(
      'delete from shared_shopping_list_items where id=$1 and couple_session_id=$2',
      [id, session.id],
    );
    if (!result.rowCount) throw itemNotFound();
    return this.listForSession(session.id);
  }

  async reorder(userId: string, itemIds: unknown) {
    const session = await this.requireSession(userId);
    if (!Array.isArray(itemIds) || itemIds.some((id) => typeof id !== 'string') || new Set(itemIds).size !== itemIds.length) {
      throw new AppError('Provide each shopping-list item exactly once.', 400, 'SHOPPING_LIST_REORDER_INVALID');
    }
    const client = await (this.dependencies.connect?.()??getPostgresPool().connect());
    try {
      await client.query('begin');
      const owned = await client.query(
        'select id from shared_shopping_list_items where couple_session_id=$1 for update',
        [session.id],
      );
      const expected = new Set<string>(owned.rows.map((row: { id: string }) => row.id));
      if (itemIds.length !== expected.size || itemIds.some((id) => !expected.has(id))) {
        throw new AppError('The reorder contains a missing or foreign item.', 409, 'SHOPPING_LIST_REORDER_SCOPE_MISMATCH');
      }
      await client.query(
        `update shared_shopping_list_items item set sort_order=ordering.position,updated_at=now()
           from unnest($1::uuid[]) with ordinality ordering(id,position)
          where item.id=ordering.id and item.couple_session_id=$2`,
        [itemIds, session.id],
      );
      await client.query('commit');
    } catch (error) {
      await client.query('rollback');
      throw error;
    } finally {
      client.release();
    }
    return this.listForSession(session.id);
  }

  private async listForSession(sessionId: string) {
    const rows = await this.query(
      'select id,name,normalized_name,quantity,measure,checked,sort_order,created_at,updated_at from shared_shopping_list_items where couple_session_id=$1 order by sort_order,created_at',
      [sessionId],
    );
    return { sessionId, items: rows.rows };
  }

  private async requireSession(userId: string): Promise<CoupleSessionRecord> {
    const session = await (this.dependencies.findActive??domainRepositories.coupleSessions.findActiveForUser.bind(domainRepositories.coupleSessions))(userId);
    if (!session || !session.memberIds.includes(userId)) {
      throw new AppError('An active pair is required.', 404, 'PAIR_SESSION_INACTIVE');
    }
    const allowed=await (this.dependencies.canPair?.(session)??entitlementService.canPairUseFeature(session, 'shared_shopping_list'));
    if (!allowed) {
      throw new AppError('FoodMatch Premium is required for shopping lists.', 403, 'PREMIUM_SHOPPING_LIST_REQUIRED', { feature: 'shopping_list' });
    }
    return session;
  }

  private query(text:string,values:readonly unknown[]=[]){return (this.dependencies.query??queryPostgres)(text,values);}
}

function clean(value: unknown) {
  const result = String(value ?? '').trim();
  return result || null;
}

function itemNotFound() {
  return new AppError('Shopping-list item not found.', 404, 'SHOPPING_LIST_ITEM_NOT_FOUND');
}
