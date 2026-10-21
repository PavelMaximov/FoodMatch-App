# Purchase foreign keys and account deletion

Migration: 20261020000200_store_purchase_account_deletion.sql.

This removes the purchase-table foreign-key blocker only. It does not implement
an account-deletion API/UI, cancel an App Store/Google Play subscription, or
certify the complete account-erasure flow.

## Behavior
- Deleting a profile (including via auth.users cascade) deletes its detailed
  store_purchase_transactions rows.
- store_purchase_identities retains the provider, kind, purchase identity and
  creation timestamp, but its user_id becomes NULL. NULL means permanently
  reserved, not available for another account.
- The binding trigger and repository reject replay/renewal into another account.
- An identity cannot be manually transferred or detached while its profile exists.
- The original migration remains unchanged; apply the new migration after it.

## Validation before deployment
No runtime environment was available when this patch was prepared.
These checks have NOT been run:
1. npm run build and npm run lint in backend.
2. With the usual test Supabase environment variables configured:
   npx ts-node src/scripts/testPurchaseReadiness.ts
3. Apply all migrations to a disposable Supabase database, then run
   npm run supabase:test:db against that explicit test database.
   premium_store_account_deletion.sql covers profile deletion, ledger retention,
   Apple/Google replay and attempted ownership transfer; tests roll back fixtures.
4. Test concurrent purchase verification and account deletion; a failed/deadlocked
   operation must roll back and be retried, never leave a projected entitlement.

Keep production unchanged until the migration and tests have been verified.
Do not undo this by deleting retained identity rows: that removes replay protection.

## Remaining release decisions
Retained purchase identifiers are not asserted to be anonymous. Define their
retention period, access restrictions and erasure basis before enabling purchases.
Automatic cross-account restoration after deletion is deliberately denied; a
future recovery/transfer process requires verified ownership and explicit policy.
Store cancellation and account deletion are separate flows.
