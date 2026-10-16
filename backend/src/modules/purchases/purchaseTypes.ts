export type StoreProvider = 'apple' | 'google';
export type StoreSubscriptionStatus = 'trialing' | 'active' | 'grace_period' | 'cancelled' | 'expired' | 'revoked';
export interface PurchaseEvidence {
  provider: StoreProvider;
  productId: string;
  purchaseEvidence: string;
}
/** Internal server output, never parsed from a client request. No raw receipts. */
export interface VerifiedStorePurchase {
  provider: StoreProvider;
  productId: string;
  externalTransactionId: string;
  originalTransactionId?: string;
  /** One-way digest of a verified Google token, never the token itself. */
  purchaseTokenHash?: string;
  status: StoreSubscriptionStatus;
  purchasedAt: Date;
  expiresAt: Date;
  environment: 'sandbox' | 'production';
}
export interface StoreTransaction extends VerifiedStorePurchase { id: string; userId: string }
export type StoreSubscriptionEvent = 'renewed' | 'expired' | 'grace_period' | 'cancelled' | 'revoked';
/** Only authenticated, cryptographically verified notifications may enter here.
 * No public webhook is registered in this readiness release. Implementations
 * must persist state then project entitlement atomically, with ordering checks.
 */
export interface StoreSubscriptionEventProcessor {
  processVerifiedEvent(event: StoreSubscriptionEvent, purchase: VerifiedStorePurchase): Promise<void>;
}
