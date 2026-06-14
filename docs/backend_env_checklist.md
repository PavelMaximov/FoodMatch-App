# Backend Environment Checklist

## Required environment variables

Create a local `.env` file from `backend/.env.example` and set placeholders without committing real secrets.

| Variable | Required | Notes |
| --- | --- | --- |
| `MONGODB_URI` | Yes | MongoDB connection string. Do not commit credentials. |
| `JWT_SECRET` | Yes | Strong secret for signing auth tokens. Do not reuse test values in production. |
| `PORT` | Yes | Local API port, usually `3000`. |
| `CLOUDINARY_CLOUD_NAME` | Yes for uploads | Cloudinary cloud name. |
| `CLOUDINARY_API_KEY` | Yes for uploads | Cloudinary API key. |
| `CLOUDINARY_API_SECRET` | Yes for uploads | Cloudinary API secret; never log or commit. |

## Commands

```bash
cd backend
npm install
npm run build
npm run dev
```

## Sanity endpoints

Run with a valid JWT where auth is required.

- `GET /api/dishes?limit=20&offset=0`
- `GET /api/dishes?limit=all`
- `GET /api/dishes?maxTotalTime=30`
- `GET /api/couples/me`
- `GET /api/auth/me`

## Startup checks

- MongoDB connects successfully.
- Development logs show `[API] METHOD /api/... status durationms`.
- Slow development logs show `[API:SLOW]` with safe `user=` only when available.
- No JWTs, passwords, Cloudinary secrets, uploaded file bodies, or full catalog response bodies appear in logs.
