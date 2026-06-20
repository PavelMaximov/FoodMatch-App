# Session Custom Dish Safety

## Current custom dish flow audit

- Custom dishes are created through the authenticated `POST /api/dishes/custom` endpoint.
- The backend, not the client, assigns ownership and session scope. User-provided `createdBy`, `coupleId`, `status`, moderation fields, and `isCustom=false` are rejected by strict request validation.
- Before this sprint, custom dishes were session-required, used legacy `status=active`, were mixed into catalog visibility filters for the active session, and arbitrary HTTPS `imageUrl` values could be submitted when creating a custom dish.
- Ownership deletion existed for creator-only deletes, but update support was missing. Deletes now hide referenced dishes instead of breaking swipe/match history.
- Prepared decks previously selected non-custom dishes with broad non-deleted status plus active custom dishes by couple. It now uses explicit public/session visibility and approved status.

## Visibility model

Custom dishes are never public for MVP local couple sessions.

| Dish kind | `isCustom` | `visibility` | `status` | `createdBy` | `coupleId` |
| --- | --- | --- | --- | --- | --- |
| Imported/public catalog dish | `false` | `public` | `approved` | empty | empty |
| Creator with active couple session | `true` | `session` | `approved` | creator user id | active couple session id |
| Creator without active couple session | `true` | `private` | `approved` | creator user id | empty |
| Deleted custom dish with swipe/match history | `true` | unchanged | `hidden` | creator user id | unchanged |

## Session-only behavior

When a user creates a dish during an active couple session, it is attached to that session only. It can be used by the creator and the creator's active couple session. It is not eligible for unrelated sessions or the global recipe catalog.

## Creator ownership

Only the creator can edit or delete a custom dish. Public/imported dishes cannot be edited or deleted through the custom dish endpoints. Unauthorized access returns a safe not-found style response where appropriate to avoid leaking private dish existence.

## Partner visibility

A partner in the same active couple session can see and swipe an approved session custom dish in that session's prepared deck. The partner cannot edit or delete the dish.

## Public catalog exclusion

Normal recipe/catalog queries return only `visibility=public` and `status=approved` dishes. Private and session custom dishes are excluded from global Recipes responses.

## Prepared deck inclusion

Prepared decks include:

1. Public approved dishes.
2. Approved session custom dishes attached to the current active couple session.

Prepared decks exclude another couple's session dishes, another user's private dishes, and hidden/deleted custom dishes.

## Image safety

Custom dish images must be uploaded through the backend upload endpoint. The upload path stores images in Cloudinary folder `foodmatch/dishes/custom`, returns `secure_url` and `public_id`, allows only JPG, PNG, and WebP images, rejects SVG, and enforces the configured upload file size limit.

Custom dish create/update rejects arbitrary external `imageUrl` values. If an image URL is submitted, it must be paired with a custom-dish Cloudinary public id generated for the current user.

## Validation rules

Custom dish inputs are trimmed and constrained:

- `name`: required, max 80 characters.
- `description`: max 500 characters.
- `cuisine`: max 50 characters.
- `type`: max 50 characters.
- `ingredients`: required, max 30 items.
- Ingredient text fields: max 80 characters.
- `steps`: required, max 20 items.
- Step text: max 500 characters.
- `cookTime`: numeric, 0-600.
- `servings`: max 50 characters.
- `mood`, `diet`, `source`, and `season`: bounded arrays/values with short string limits.

Friendly errors are used for missing names, ingredients, steps, invalid images, unavailable dishes, and creator-only edit/delete operations.

## Deferred public moderation/admin flow

The following remain intentionally deferred: public dish submission, admin roles/endpoints, Retool moderation, public approval queues, AI moderation, report systems, and a full admin dashboard.

## Sprint 19.1 prepared deck invalidation hotfix

Root cause: prepared decks are persisted on the couple session. When a session custom dish was created after the shared deck was already ready, the dish was saved correctly but the existing `preparedDeck.dishIds` list was not updated, so both partners continued loading the old deck.

Hotfix strategy:

- On session custom dish create/update, if the active couple session has a ready prepared deck with existing dish ids, insert the custom dish id at the front of the persisted deck without duplicating it.
- On session custom dish delete/hide, remove the custom dish id from the persisted deck without deleting swipes, matches, filters, confirmations, or the couple session.
- Session custom dishes are included in prepared deck candidate generation even when they do not match cuisine filters, because the creator explicitly added them to the current session.
- Session custom dishes receive high deterministic scoring priority in the prepared deck while preserving no-duplicate ordering.
- Existing deck GET responses filter out hidden/deleted or no-longer-visible dishes defensively.
- The Flutter Add Dish flow clears local prepared deck state after a successful add so the Swipe screen reloads the updated backend prepared deck instead of reusing stale in-memory state.
