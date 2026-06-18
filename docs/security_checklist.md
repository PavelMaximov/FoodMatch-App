# FoodMatch MVP Security Checklist

## Backend environment variables

Set these in backend runtime environments and keep `.env` files out of Git:

- `NODE_ENV` (`development`, `test`, or `production`)
- `MONGODB_URI` (must point to the active app database, `foodmatch`, not `test` unless intentionally running a test environment)
- `JWT_SECRET` (at least 32 characters)
- `JWT_EXPIRES_IN` (MVP default: `7d`)
- `CORS_ORIGINS` (comma-separated explicit browser origins)
- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

## Rules

- `.env` must not be committed.
- `.env.example` may contain placeholder values only.
- `JWT_SECRET` must be unique per environment and at least 32 characters.
- Cloudinary API secrets must exist only on the backend.
- MongoDB application users should not be root/admin users. Use a database user with `readWrite` on `foodmatch` for the app.
- MongoDB Atlas IP access should be restricted wherever possible.
- Production CORS origins must be explicit; do not use `*` in production.

## Manual release checklist

- [ ] Confirm `.gitignore` includes `.env` and environment-specific variants.
- [ ] Rotate secrets if they were ever exposed in logs, Git, tickets, screenshots, or chat.
- [ ] Use a separate least-privilege MongoDB user for the app (`readWrite` on `foodmatch`).
- [ ] Run `npm run audit:user-emails` against production/staging before normalizing any legacy mixed-case duplicate users; do not delete users automatically.
- [ ] Disable or remove unused public write endpoints.
- [ ] Review Cloudinary upload presets and disable unsigned/public presets not needed by the app.
- [ ] Confirm auth tokens, passwords, MongoDB URIs, and Cloudinary secrets are not logged.
- [ ] Confirm CORS origins match only deployed web/admin URLs plus approved local dev URLs.

## Sprint 18 completed Flutter client protection items

- [x] Android sensitive-route screen security using `FLAG_SECURE` via a Flutter platform channel.
- [x] App switcher privacy overlay for inactive/paused/hidden/detached lifecycle states.
- [x] Production HTTPS guard that blocks `http://` API URLs in release builds by default.
- [x] Certificate pinning foundation with local-dev HTTP disabled from pinning and production-only enablement gates.

## Still deferred

- Final production certificate pins after a real production domain/certificate chain exists.
- UGC moderation and admin approval workflows.
- Deeper production infrastructure hardening such as WAF tuning, centralized audit log retention, secret rotation automation, and SIEM alerting.
- Production email provider.
