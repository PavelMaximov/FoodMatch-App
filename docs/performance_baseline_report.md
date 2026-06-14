# Sprint 15 Performance Baseline Report

Use debug backend `[API]` / `[API:SLOW]` logs and Flutter API timing logs to fill `Current result` during MVP test runs. Codex could not manually run the app in this environment, so runtime results remain TODO.

| Area | What to measure | Target | Current result | Notes |
| --- | --- | --- | --- | --- |
| App startup | Cold launch to first interactive screen | No red screens; restore token without visible crash | TODO | Verify release mode on a physical device/emulator. |
| Login request | `POST /api/auth/login` duration and UI transition | Normal local API < 500ms | TODO | Confirm friendly error on 401/connection failure. |
| Recipes first load | `GET /api/dishes?limit=20&offset=0` | Normal local API < 500ms; no duplicate request storm | TODO | Watch backend count + Flutter timing logs. |
| Category first page | First category `GET /api/dishes?...` | Normal local API < 500ms | TODO | Validate category params match configured category. |
| Category pagination | Next page offset request | Normal local API < 500ms; pagination stops when `hasMore=false` | TODO | Confirm small totals do not hang load-more. |
| Recipe detail open | `GET /api/dishes/:id` and render | Normal local API < 500ms | TODO | Images may continue loading after detail appears. |
| Search response | Debounced `GET /api/dishes?search=...` | Normal local API < 500ms; no request storm | TODO | Verify debounce does not overlap excessive calls. |
| Favorite toggle | Save/unsave request and visual update | Normal local API < 500ms; no raw backend errors in UI | TODO | Duplicate save should show friendly conflict message. |
| Avatar upload | `POST /api/uploads/avatar` | Uploads visible with progress/placeholder; slow only > 3000ms | TODO | Confirm no file contents or secrets in logs. |
| Create session | `POST /api/couples` | Normal local API < 500ms | TODO | Verify active-session conflict text. |
| Join session | `POST /api/couples/join` | Normal local API < 500ms | TODO | Verify invalid code and already-in-session errors. |
| Filter-state sync | `GET/PUT/POST /api/couples/filter-state...` | Normal local API < 500ms; polling does not overlap | TODO | Watch `[SessionSync]` and dedup logs. |
| Deck prepare | `POST /api/couples/deck/prepare` | Deck prepare < 1500ms; prepare once | TODO | Expected slowest non-upload endpoint. |
| Swipe request | `POST /api/swipes` | Normal local API < 500ms; duplicate prevention | TODO | Duplicate key/raw Mongo errors must not reach UI. |
| Match overlay | Match creation to overlay display | No red screens; no duplicate match overlay | TODO | Confirm overlay appears only for mutual like. |
| Matches list | `GET /api/swipes/matches` | Normal local API < 500ms | TODO | Confirm empty state vs real results. |
| Profile load | `GET /api/auth/me`, couple state | Normal local API < 500ms | TODO | Confirm avatar placeholder/relogin avatar. |
| Image-heavy scrolling | Recipe/category scrolling with network images | Smooth enough for MVP; placeholders for broken images | TODO | Watch memory/network churn and broken image fallback. |

## Likely slow endpoints to watch

- `GET /api/dishes?limit=all`: full catalog response; should be cached/deduplicated on the Flutter side and avoided for normal category browsing.
- `GET /api/dishes?...&sort=cookTime`: uses aggregation for computed cook-time sorting; watch category pages such as Quick & Easy and Under 30 minutes.
- `GET /api/dishes?search=...`: regex/text-like matching can be slower as catalog grows; verify debounce prevents request storms.
- `POST /api/couples/deck/prepare`: expected hotspot because it evaluates filters and writes a prepared deck; slow threshold is 1500ms.
- `POST /api/uploads/avatar` and `POST /api/uploads/custom-dish-image`: expected network-bound uploads; slow threshold is 3000ms.
