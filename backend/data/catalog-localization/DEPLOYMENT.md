# Verified hosted deployment — 2026-11-22

Project: foodmatch-dev (`vdvsaxfnakjkemftmejc`).
Migration: `20261122202618_catalog_content_translations`.

- Full source guard passed against the hosted catalog; transactional dry-run rolled back.
- Apply committed all 239 curated recipes / 4,005 source-to-German mappings.
- Total dishes: 242; custom recipes: 3; translated custom recipes: 0.
- Canonical dish checksum before and after: `4e437f21750be6a050da1107ffff4d00`.
  Computed over `to_jsonb(d) - 'updated_at' - 'content_translations'`, ordered by ID.
- Anonymous and authenticated direct UPDATE privilege on dishes remains false.
- No accounts, sessions, likes or existing grocery rows were changed.
- Initial translation column was absent; migration initialized `{}`. Guarded rollback
  removes the deployed `de` key only; no original translations were overwritten.

The backend process itself has not been deployed/restarted from this environment.
See README for client/backend acceptance checks and the rollback generator.

Security advisors were compared before/after: no new finding introduced. Existing
notices remain: server-only tables intentionally have RLS without client policies;
`handle_new_auth_user()` has broad EXECUTE grants; leaked-password protection is disabled.
These authentication settings were not changed by the catalog deployment.
References:
- https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

Validation: backend build and full `check:backend` passed, as did catalog translation,
standalone shared-grocery translation, translation-package and PGlite deployment tests.
The optional aggregate `testPremiumServices.ts` reached the new grocery test successfully
but its existing leave-history fixture requires a database/updated transaction mock;
it was not counted as a passing full suite. Flutter execution remains unverified here.
