# FoodMatch MVP Security Checklist

## Backend environment variables

Set these in backend runtime environments and keep `.env` files out of Git:

- `NODE_ENV` (`development`, `test`, or `production`)
- `MONGODB_URI`
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
- MongoDB application users should not be root/admin users.
- MongoDB Atlas IP access should be restricted wherever possible.
- Production CORS origins must be explicit; do not use `*` in production.

## Manual release checklist

- [ ] Confirm `.gitignore` includes `.env` and environment-specific variants.
- [ ] Rotate secrets if they were ever exposed in logs, Git, tickets, screenshots, or chat.
- [ ] Use a separate least-privilege MongoDB user for the app.
- [ ] Disable or remove unused public write endpoints.
- [ ] Review Cloudinary upload presets and disable unsigned/public presets not needed by the app.
- [ ] Confirm auth tokens, passwords, MongoDB URIs, and Cloudinary secrets are not logged.
- [ ] Confirm CORS origins match only deployed web/admin URLs plus approved local dev URLs.
