import { AppError } from '../../core/errors/AppError';
import { PurchaseEvidence, StoreProvider, VerifiedStorePurchase } from './purchaseTypes';
import { StorePurchaseRepository, VerifiedEntitlementProjector } from './storePurchaseRepository';

export interface PurchaseVerifier {
  verify(evidence: PurchaseEvidence, authenticatedUserId: string): Promise<VerifiedStorePurchase>;
}
export interface ApplePurchaseVerifier extends PurchaseVerifier { readonly provider: 'apple' }
export interface GooglePurchaseVerifier extends PurchaseVerifier { readonly provider: 'google' }
export class NotConfiguredPurchaseVerifier implements PurchaseVerifier {
  async verify(): Promise<VerifiedStorePurchase> {
    throw new AppError('Store purchase verification is not configured.', 503,
      'STORE_PURCHASE_VERIFICATION_NOT_CONFIGURED');
  }
}
export class PurchaseVerificationService {
  constructor(private readonly repository: StorePurchaseRepository,
    private readonly projector: VerifiedEntitlementProjector,
    private readonly verifiers: Record<StoreProvider, PurchaseVerifier> = {
      apple: new NotConfiguredPurchaseVerifier(), google: new NotConfiguredPurchaseVerifier(),
    }) {}

  async verifyAndSync(authenticatedUserId: string, evidence: PurchaseEvidence) {
    let verified: VerifiedStorePurchase;
    try {
      verified = await this.verifiers[evidence.provider].verify(evidence, authenticatedUserId);
    } catch (error) {
      if (error instanceof AppError && error.code === 'STORE_PURCHASE_VERIFICATION_NOT_CONFIGURED') throw error;
      // Never pass a provider SDK error (which may contain evidence) to logs or clients.
      throw new AppError('Store purchase could not be verified.', 502, 'STORE_PURCHASE_VERIFICATION_FAILED');
    }
    if (verified.provider !== evidence.provider || verified.productId !== evidence.productId) {
      throw new AppError('Store product does not match.', 400, 'STORE_PURCHASE_PRODUCT_MISMATCH');
    }
    try {
      const transaction = await this.repository.persistAndProject(authenticatedUserId, verified, this.projector);
      return { backendVerified: true, transactionId: transaction.id };
    } catch (error) {
      if (error instanceof AppError && ['STORE_PURCHASE_ACCOUNT_CONFLICT', 'STORE_ENTITLEMENT_PROJECTION_NOT_CONFIGURED',
        'INVALID_VERIFIED_STORE_PURCHASE'].includes(error.code ?? '')) throw error;
      throw new AppError('Store purchase could not be saved.', 503, 'STORE_PURCHASE_PERSISTENCE_FAILED');
    }
  }
}
