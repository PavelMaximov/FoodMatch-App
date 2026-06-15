# Error Tracking Plan

No crash/error SDK is installed for the MVP in Sprint 15. This document records future options and safe data boundaries.

## Future options

- Firebase Crashlytics for Flutter crash reporting.
- Sentry for Flutter and Node/Express exception and performance visibility.

## Track later

- Uncaught Flutter errors.
- API failures by endpoint, status, and friendly error category.
- Auth expiration/session restore failures.
- Failed avatar/custom dish upload.
- Failed deck prepare.
- Failed swipe.
- Failed match load.

## Do not collect

- Passwords.
- JWT tokens.
- Private request bodies.
- Uploaded raw files.
- Cloudinary API secret.
- Full user objects or full dish catalog payloads.

## Suggested MVP events for future analytics/error breadcrumbs

- `app_start`
- `login_success`
- `recipe_open`
- `favorite_toggle`
- `session_create`
- `session_join`
- `filters_confirm`
- `deck_prepare_success`
- `swipe_sent`
- `match_created`
- `avatar_upload_success`

## Implementation notes for a later sprint

- Gate SDK initialization behind release/staging configuration.
- Scrub request headers and bodies before sending breadcrumbs.
- Prefer endpoint templates (`GET /api/dishes`) over full query strings when queries may include user-entered search text.
- Keep opt-out/deletion requirements aligned with store/privacy policy decisions before production release.
