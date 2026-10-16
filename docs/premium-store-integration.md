# Premium store integration readiness

Premium's internal entitlement architecture is ready; Apple and Google stores are
**not connected**. This change contains no store SDK, product requests, real
purchase/restore, receipt/token verification, introductory-offer eligibility,
notifications, or ads. Configuring product IDs alone enables none of these.

## Flutter boundary

`PremiumPurchaseCoordinator` isolates products, purchase, and restore from the
compact screen. The default `UnavailablePremiumPurchaseCoordinator` returns an
explicit `notConfigured` result and the existing FoodMatch informational notice.
Product loading safely falls back to €3.99/month, €29.99/year, and annual 7-day
trial marketing copy. These are marketing fallbacks, never billing data.

Set `--dart-define=PREMIUM_MONTHLY_PRODUCT_ID=...` and
`--dart-define=PREMIUM_YEARLY_PRODUCT_ID=...` separately in each platform's build
configuration. Missing values are safe; both IDs being present still leaves the
adapter unavailable. Do not put IDs in widgets. The domain holds provider,
product ID, localized/raw prices, currency, billing period, availability and
introductory-offer/eligibility metadata. Store metadata replaces fallback copy
when available; unknown eligibility must never be shown as an eligible trial.

A future adapter must observe pending/completed transaction updates, submit
opaque evidence to the authenticated backend and finish/acknowledge transactions
only under the store's required verified processing policy. It may return
`purchased` with `backendVerified: true` only after backend verification,
persistence and projection succeed. The controller then calls
`PremiumProvider.forceRefresh()`. The result itself never writes entitlement;
even a successful result followed by a Free API response keeps access Free.
Pending, cancelled, error and unverified results do not refresh or grant access.

## Backend API

Both routes require the existing bearer authentication middleware:

- `POST /api/purchases/verify`
- `POST /api/purchases/restore/sync`

Both take exactly `{ provider: "apple" | "google", productId: string,
purchaseEvidence: string }`. Restore sync will verify one store evidence item
at a time; it does not mean all owned purchases were restored. Evidence is an
opaque string, maximum 100,000 characters; product ID maximum 255 characters.
Unknown fields, including `userId`, `tier`, `status`, `expiresAt` and `isPremium`,
are rejected with 400. Ownership comes only from authenticated `req.userId`.

Current valid requests return HTTP 503 and code
`STORE_PURCHASE_VERIFICATION_NOT_CONFIGURED`, without accessing storage or
changing `user_subscriptions`. There is no public notification webhook.
Future success contract is `{ backendVerified: true, transactionId: string }`;
the client must separately refresh effective entitlements.

`ApplePurchaseVerifier` / `GooglePurchaseVerifier` are server interfaces; the
production wiring uses only `NotConfiguredPurchaseVerifier`. A future verifier
must validate cryptographic evidence, app/package, product allowlist, environment,
account binding (Apple appAccountToken / Google obfuscated account identity),
expiry/revocation, and authoritative store state. It must not echo evidence in
errors. Provider/storage errors are replaced with stable sanitized errors.

## Storage, ownership and atomic projection

The migration adds service-only RLS tables with no client policies or grants:

- `store_purchase_transactions`: verified transaction state and dates, provider,
  product, environment, transaction/original IDs, and a Google token SHA-256
  digest. No raw receipt, token, SDK response or unrestricted JSON payload.
- `store_purchase_identities`: global primary key on provider / identity kind /
  value. It binds individual transaction IDs, Apple original transaction chains,
  and Google token digests to one profile. Renewals may share an original ID or
  token and still have separate transaction records.

A future Google verifier computes the lowercase SHA-256 hex digest of the exact
verified token. If store APIs later require retaining usable tokens, design a
separate encrypted, access-controlled secret store with retention/rotation;
never replace the digest with plaintext or log evidence.

`PostgresStorePurchaseRepository.findByIdentity` provides lookup;
`persistAndProject` claims identities under transaction locks, verifies ownership,
and upserts state by provider/external transaction ID. Same-account replay reuses
the same row. Cross-account replay or conflicting immutable identity metadata
returns 409 `STORE_PURCHASE_ACCOUNT_CONFLICT`. A database trigger also claims
identities on every transaction write and prevents immutable identity/ownership
changes, protecting future writes that do not use this repository. Concurrent claims serialize on the
unique identity ledger; account-level advisory locks serialize projections.
`VerifiedEntitlementProjector.projectVerifiedEntitlement` receives the same SQL
transaction query: transaction state and `user_subscriptions` must commit or
roll back together. Storage failure grants nothing. The default projector is
also explicitly not configured; this release has **no active store projector**.

The intended flow is:

    verified store state -> store_purchase_transactions -> user_subscriptions
      -> EntitlementService -> Flutter PremiumProvider

`user_subscriptions` remains the authoritative effective entitlement projection.
Neither transaction rows nor client purchase results grant access by themselves.
Production refinements required before enabling an adapter/projector: authoritative
store event ordering and stale-update rejection, linked/replacement Google tokens,
upgrade/downgrade product transitions, multi-subscription reconciliation,
sandbox/production isolation, cancellation versus revocation semantics, transaction
completion/acknowledgement retries and operational retention. Do not enable the
current generic upsert for out-of-order notifications without those rules.
The schema deliberately claims identities globally across environments to fail
closed on collision. `ON DELETE RESTRICT` preserves replay protection; finalize
account erasure/tombstone retention policy before launch.

`StoreSubscriptionEventProcessor` defines the future verified-event boundary for
renewed, expired, grace-period, cancelled/non-renewing and refunded/revoked events.
A real processor must authenticate notifications, retrieve authoritative state,
reject stale events, and use the same atomic persistence/projection path.

## Apple registration and implementation still required

1. Apple Developer membership and App Store Connect app/bundle ID.
2. Subscription group, monthly/yearly products, localized pricing, product IDs,
   and annual 7-day introductory offer in App Store Connect.
3. App Store Server API issuer ID, key ID, private signing key in server secret
   storage; bundle/app identifiers and allowed environments in server config.
4. Real StoreKit adapter, signed transaction/JWS validation and Server API
   integration; account binding and introductory-offer eligibility.
5. Server Notifications V2 endpoints with real signature verification,
   authoritative reconciliation, replay protection and idempotent processing.
6. Sandbox testers, devices and QA of renewals, billing retry/grace, cancellation,
   refunds/revocations, restore, account switching and outages.

## Google registration and implementation still required

1. Play Console app/package ID and subscription products/base plans/offers.
2. Monthly/yearly product IDs and annual trial/offer configuration, localized
   prices and eligibility rules.
3. Service account with Play Developer API access, credentials in server secret
   storage, package name and allowed environments in backend config.
4. Real Play Billing adapter, purchase-token verification, account binding,
   acknowledgement/retry policy and replacement/linked-token handling.
5. RTDN/Pub/Sub project, topic and authenticated subscription/delivery identity;
   authenticated event handling followed by authoritative Developer API reads.
6. License testers and QA covering the same lifecycle, restore, account and
   outage cases as Apple.

Only the two Flutter `PREMIUM_*_PRODUCT_ID` values are consumed by this PR.
Backend app/bundle/package identifiers, product allowlists, environment settings,
Apple issuer/key/private-key secret references, Google service-account secret
references and Pub/Sub identifiers are future configuration requirements, not
currently implemented environment switches. Do not add secret values to source.

## Validation

`npm run test:purchase-readiness` covers unavailable verification, strict API
contracts/authentication, ownership/replay, renewal identity handling, sanitized
errors and rollback using the production repository with a transactional SQL
test double. Flutter purchase tests cover configuration, both plan selections,
unavailable operations, backend-verified-only refresh, metadata and fallback UI.
`supabase/tests/premium_store.sql` adds live pgTAP checks for schema, RLS/grants,
identity uniqueness, raw-token rejection and no automatic entitlement grant.
Run it with `npm run supabase:test:db` against a local migrated Supabase database.
