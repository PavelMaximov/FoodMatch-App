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
