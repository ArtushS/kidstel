# Admin panel groundwork (plan)

This document outlines a safe, incremental path to add an admin web app without
breaking the existing Flutter app.

## Goals

- Remote policy controls (feature flags, limits, allow-lists).
- Simple content/catalog management for story setup (heroes/locations/types).
- Audit trail for changes.

## Non-goals (for the first iteration)

- No direct access to end-user story text/history.
- No privileged operations in the Flutter client.

## Proposed data model (Firestore)

### 1) Policy document (global)

Collection: `admin`

Document: `policy`

Suggested fields:

- `enabled: bool`
- `allowAutoIllustrations: bool`
- `allowedLanguageCodes: string[]` (nullable/optional)
- `maxStoryLengthHint: number` (nullable/optional)

Flutter shared model: `AdminPolicyConfig` in `lib/shared/models/admin_policy_config.dart`.

### 2) Story setup catalogs

Existing (already used by the app):

- `catalog/story_setup/heroes`
- `catalog/story_setup/locations`
- `catalog/story_setup/types`

Each document should have:

- `name: string` or localized schema
- `iconUrl: string` (https or gs://)
- `order: number`

## Integration points (Flutter)

- Settings:
  - Add an optional “policy override” layer *above* user preferences.
  - Example: if policy forbids auto illustrations, UI toggle is disabled.

- Story generation:
  - Before sending requests, clamp outgoing fields to policy.

## Admin app (tech suggestion)

- Stack: Node/TypeScript + React + Firebase Admin SDK.
- Auth: Google Sign-In; restrict access by allow-list of emails.
- Deployment: Firebase Hosting + Cloud Functions (optional).

## Next steps

1) Add a repository to read `admin/policy` with caching.
2) Wire policy into settings controller as an override (no breaking changes).
3) Build a minimal admin UI:
   - Toggle illustrations
   - Edit allowed languages
   - Save with timestamp + editor email
