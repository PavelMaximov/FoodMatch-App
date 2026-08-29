# FoodMatch Backend (MVP)

Node.js + TypeScript + Express + MongoDB backend for FoodMatch mobile app.

## Run

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

## API overview

Base URL: `/api`

- Auth: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`
- Couples: `POST /couples/create`, `POST /couples/join`, `GET /couples/me`, `POST /couples/leave`, `POST /couples/reset`
- Dishes: `GET /dishes`, `GET /dishes/:id`, `GET /dishes/random`, `GET /dishes/search?q=`
- Swipes: `POST /swipes`, `GET /swipes/matches`, `GET /swipes/history`
- Matches: `GET /matches`

## Notes

- Dishes use hybrid model: TheMealDB is external source, backend normalizes and caches in local `Dish` documents.
- Reset means deleting swipes and matches for current active couple session while keeping session active.
- Leaving a 2-member active session closes it; leaving last member from one-member session deletes it.

## Media storage strategy

FoodMatch stores dynamic/content media in Cloudinary and keeps static UI assets bundled with Flutter for offline reliability.

### Backend Cloudinary configuration

Set these backend-only environment variables; never expose `CLOUDINARY_API_SECRET` to Flutter:

- `CLOUDINARY_CLOUD_NAME`
- `CLOUDINARY_API_KEY`
- `CLOUDINARY_API_SECRET`

### Cloudinary folders

- `foodmatch/users/avatars` — authenticated user avatar uploads.
- `foodmatch/dishes/custom` — user-uploaded custom dish photos.
- `foodmatch/dishes/catalog` — manually managed catalog dish images for `dishes.imageUrl`.
- `foodmatch/app/banners` — optional remote app banners.
- `foodmatch/app/promos` — optional remote promotional images.

### Catalog dish images

Existing catalog `imageUrl` values remain valid and do not require migration. New catalog images can be uploaded manually to Cloudinary under `foodmatch/dishes/catalog`, then the returned `secure_url` can be stored in `dishes.imageUrl`. A future admin-only upload endpoint or migration script can automate this when admin roles exist.

### Flutter static assets

Flutter should continue bundling core UI media locally in `assets/icons/`, `assets/logos/`, `assets/media/`, and `assets/images/`, including logos, bottom navigation icons, empty states, default avatar placeholders, default dish placeholders, and decorative SVG/PNG assets. Static UI assets should not be uploaded to Cloudinary.

## Local mobile/web API URLs

Backend defaults for local development:

```bash
PORT=4000
HOST=0.0.0.0
FRONTEND_URL=http://localhost:3000
```

Flutter examples:

```bash
# Flutter Web / Chrome on the same machine
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000

# Android emulator
flutter run -d emulator-5554 --dart-define=ANDROID_EMULATOR=true --dart-define=API_BASE_URL=http://10.0.2.2:4000

# Physical Android/iOS device on the same Wi-Fi (replace with your LAN IP)
flutter run -d <deviceId> --dart-define=API_BASE_URL=http://192.168.0.39:4000
```

## Production readiness (post Mongo migration)
MongoDB is migration-tooling-only and absent from the server import graph. See [`../docs/production_readiness.md`](../docs/production_readiness.md) for architecture, configuration, run commands, common errors, and rollback. Follow [`../docs/deploy_checklist.md`](../docs/deploy_checklist.md) for every deployment.
