# Auth Security v2

## Access token TTL
Access tokens are stateless JWTs signed with `JWT_SECRET` and expire with `JWT_ACCESS_EXPIRES_IN` (default `15m`). They contain only `userId`/`sub` and email. Access tokens are not stored in MongoDB.

## Refresh token rotation
Login and registration now return a compatible `token` access token plus additive `accessToken` and `refreshToken` fields. Refresh tokens are high-entropy random values. MongoDB stores only a SHA-256 `tokenHash` in the `RefreshToken` collection with `familyId`, expiry, revocation, replacement, reuse, IP, and user-agent metadata.

`POST /api/auth/refresh` hashes the presented token, verifies it is active, revokes it, creates a replacement in the same family, and returns a new token pair. A refresh token can be used once.

## Reuse detection
If an already-revoked refresh token is presented, the backend marks it with `reusedAt`, revokes the whole token family, and returns `401`. The user must log in again.

## Logout
`POST /api/auth/logout` accepts an optional `refreshToken`, revokes it if present, and is idempotent. `POST /api/auth/logout-all` requires an access token and revokes all active refresh tokens for the user.

## Email verification
Users have `emailVerified` and `emailVerifiedAt`. New local users start unverified and receive an email verification token. Verification tokens are high-entropy random values; MongoDB stores only a SHA-256 hash in `EmailVerificationToken` with `expiresAt`, `usedAt`, and `sentToEmail`.

`POST /api/auth/resend-verification` requires auth, is rate limited, invalidates prior unused tokens, and sends a new verification link. `POST /api/auth/verify-email` (or the dev GET link) validates the token and marks the user verified.

## Dev email mode
`EMAIL_PROVIDER=dev` logs a clearly marked dev-only verification link/code when not in production. Production does not log verification tokens.

## Verification gating
`REQUIRE_EMAIL_VERIFICATION=false` by default so local/dev flows continue normally while verification state is visible. If enabled, auth responses include `requireEmailVerification=true` for unverified users and Flutter routes them to the verification screen instead of the main app. Existing users should be migrated before enabling the gate.

## Production environment checklist
- Set a strong `JWT_SECRET` (32+ characters).
- Set `JWT_ACCESS_EXPIRES_IN=15m` and `JWT_REFRESH_EXPIRES_IN=30d` unless a different risk profile is approved.
- Configure `EMAIL_PROVIDER`, `EMAIL_FROM`, and `APP_PUBLIC_URL`.
- Run the legacy user verification migration before enabling `REQUIRE_EMAIL_VERIFICATION=true`.
- Monitor refresh-token reuse events and 401 rates.

## Migration for existing users
Run `CONFIRM_MIGRATION=true npm run migrate:mark-existing-users-verified` from `backend/`. The script marks only users where `emailVerified` is missing as verified and does not change users explicitly set to `false`.

## Manual QA checklist
1. Register returns `token`, `accessToken`, `refreshToken`, and lower-case email.
2. Login returns a fresh token pair.
3. `/auth/me` works with a valid access token.
4. `/auth/refresh` rotates the refresh token.
5. Reusing an old refresh token revokes the family.
6. Logout revokes the current refresh token and clears Flutter state.
7. Logout-all revokes all user refresh tokens.
8. Resend verification creates a token and rate limits spam.
9. Verify email sets `emailVerified=true`.
10. Flutter refreshes once on 401, deduplicates concurrent refreshes, retries the original request, and clears tokens only if refresh fails.
