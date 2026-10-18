import { PoolClient } from 'pg';
import { AppError } from '../../core/errors/AppError';
import { getPostgresPool } from '../../shared/db/postgresClient';
import { StoreProvider, StoreTransaction, VerifiedStorePurchase } from './purchaseTypes';

export type StoreQuery = PoolClient['query'];
/** Must update user_subscriptions using THIS transaction's query only. Future
 * projector must reconcile all store subscriptions and reject stale events.
 */
export interface VerifiedEntitlementProjector {
  projectVerifiedEntitlement(transaction: StoreTransaction, query: StoreQuery): Promise<void>;
}
export class NotConfiguredEntitlementProjector implements VerifiedEntitlementProjector {
  async projectVerifiedEntitlement(): Promise<void> {
    throw new AppError('Store entitlement projection is not configured.', 503,
      'STORE_ENTITLEMENT_PROJECTION_NOT_CONFIGURED');
  }
}
export interface StorePurchaseIdentity {
  provider: StoreProvider;
  kind: 'transaction' | 'original_transaction' | 'purchase_token_hash';
  value: string;
}
export function purchaseIdentities(purchase: VerifiedStorePurchase): StorePurchaseIdentity[] {
  if (!purchase.externalTransactionId?.trim() || !purchase.productId?.trim() ||
      !['apple', 'google'].includes(purchase.provider) ||
      !['trialing', 'active', 'grace_period', 'cancelled', 'expired', 'revoked'].includes(purchase.status) ||
      !['sandbox', 'production'].includes(purchase.environment) ||
      !Number.isFinite(purchase.purchasedAt?.getTime()) || !Number.isFinite(purchase.expiresAt?.getTime()) ||
      (purchase.provider === 'apple' && !purchase.originalTransactionId?.trim()) ||
      (purchase.provider === 'google' && !/^[a-f0-9]{64}$/.test(purchase.purchaseTokenHash ?? ''))) {
    throw new AppError('Invalid verified purchase.', 400, 'INVALID_VERIFIED_STORE_PURCHASE');
  }
  const identities: StorePurchaseIdentity[] = [
    { provider: purchase.provider, kind: 'transaction', value: purchase.externalTransactionId },
  ];
  if (purchase.provider === 'apple') identities.push({ provider: 'apple', kind: 'original_transaction', value: purchase.originalTransactionId! });
  if (purchase.provider === 'google') identities.push({ provider: 'google', kind: 'purchase_token_hash', value: purchase.purchaseTokenHash! });
  return identities.sort((a, b) => a.kind.localeCompare(b.kind));
}
export interface StorePurchaseRepository {
  findByIdentity(identity: StorePurchaseIdentity): Promise<{ userId: string } | null>;
  persistAndProject(userId: string, purchase: VerifiedStorePurchase,
    projector: VerifiedEntitlementProjector): Promise<StoreTransaction>;
}
export class PostgresStorePurchaseRepository implements StorePurchaseRepository {
  constructor(private readonly pool = getPostgresPool) {}
  async findByIdentity(identity: StorePurchaseIdentity) {
    const result = await this.pool().query<{ user_id: string }>(
      'select user_id from public.store_purchase_identities where provider=$1 and identity_kind=$2 and identity_value=$3',
      [identity.provider, identity.kind, identity.value]);
    return result.rows[0] ? { userId: result.rows[0].user_id } : null;
  }
  async persistAndProject(userId: string, purchase: VerifiedStorePurchase, projector: VerifiedEntitlementProjector) {
    const identities = purchaseIdentities(purchase);
    const client = await this.pool().connect();
    try {
      await client.query('begin');
      // Serialize an account's projection and claim every identity globally.
      await client.query('select pg_advisory_xact_lock(hashtext($1))', [`store-purchases:${userId}`]);
      for (const identity of identities) {
        await client.query(`insert into public.store_purchase_identities(provider,identity_kind,identity_value,user_id)
          values($1,$2,$3,$4) on conflict do nothing`, [identity.provider, identity.kind, identity.value, userId]);
        const owner = await client.query<{ user_id: string }>(`select user_id from public.store_purchase_identities
          where provider=$1 and identity_kind=$2 and identity_value=$3 for update`, [identity.provider, identity.kind, identity.value]);
        if (owner.rows[0]?.user_id !== userId) throw new AppError('Purchase belongs to another account.', 409, 'STORE_PURCHASE_ACCOUNT_CONFLICT');
      }
      const result = await client.query<{ id: string }>(`insert into public.store_purchase_transactions
        (user_id,provider,product_id,external_transaction_id,original_transaction_id,purchase_token_hash,status,purchased_at,expires_at,environment)
        values($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
        on conflict(provider,external_transaction_id) do update set
          status=excluded.status, expires_at=excluded.expires_at, updated_at=now()
        where store_purchase_transactions.user_id=excluded.user_id
          and store_purchase_transactions.product_id=excluded.product_id
          and store_purchase_transactions.original_transaction_id is not distinct from excluded.original_transaction_id
          and store_purchase_transactions.purchase_token_hash is not distinct from excluded.purchase_token_hash
          and store_purchase_transactions.environment=excluded.environment
        returning id`, [userId, purchase.provider, purchase.productId, purchase.externalTransactionId,
        purchase.originalTransactionId ?? null, purchase.purchaseTokenHash ?? null, purchase.status,
        purchase.purchasedAt, purchase.expiresAt, purchase.environment]);
      if (!result.rows[0]) throw new AppError('Purchase identity conflict.', 409, 'STORE_PURCHASE_ACCOUNT_CONFLICT');
      const transaction = { ...purchase, id: result.rows[0].id, userId };
      await projector.projectVerifiedEntitlement(transaction, client.query.bind(client));
      await client.query('commit');
      return transaction;
    } catch (error) {
      await client.query('rollback');
      throw error;
    } finally { client.release(); }
  }
}
