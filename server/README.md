# KidsTel Story Agent (Cloud Run)

Express + TypeScript service that:
- exposes POST `/v1/story/create` and POST `/v1/story/continue`
- also supports a backward-compatible single endpoint POST `/` that dispatches by `body.action` (`generate` / `continue`)
- exposes POST `/v1/story/illustrate` and supports `action: "illustrate"` (never returns 501)
- verifies Firebase Auth ID token + Firebase App Check token
- calls Gemini on Vertex AI
- enforces kid-safe moderation policy
- stores sessions/audit to Firestore via Admin SDK

See `src/env.ts` for environment variables.

## Endpoints

### `POST /` (backward compatible)

Flutter currently posts to a single `STORY_AGENT_URL` with an `action` field.

- `action: "generate"` → handled like `/v1/story/create`
- `action: "continue"` → handled like `/v1/story/continue`
- `action: "illustrate"` → handled like `/v1/story/illustrate` (returns 200 with placeholder if disabled)

### `POST /v1/story/create`
Creates a new story and returns a `GenerateStoryResponse`-shaped JSON.

### `POST /v1/story/continue`
Continues an existing story by `storyId` and returns the next chapter.

### `POST /v1/story/illustrate`
Never returns 501. If illustrations are disabled by policy, returns a safe placeholder response (200).

### `GET /healthz`
Returns `{ ok: true }`.

## Auth & App Check

This service expects:

- `Authorization: Bearer <Firebase Auth ID token>`
- `X-Firebase-AppCheck: <Firebase App Check token>`

Enforcement is controlled via env vars:

- `AUTH_REQUIRED` (default: true)
- `APPCHECK_REQUIRED` (default: true)

## Firestore collections written

- `stories/{storyId}`: story session with `chapters[]`
- `story_audit/{requestId}`: audit record (allowed/blocked)
- `usage_daily/{uid_yyyymmdd}`: daily quota counter

## Admin policy (fail-closed)

Runtime controls are loaded from ONE Firestore document:

- `admin_policy/runtime`

Cache TTL: ~60s.

If policy cannot be read/parsed, the service fails closed:

- story generation is treated as disabled (503)

Policy fields (strict; unknown fields rejected):

- `enable_story_generation` (bool)
- `enable_illustrations` (bool)
- `model_allowlist` (string[])
- `max_output_tokens` (int)
- `temperature` (0..1.2)
- `max_input_chars`, `max_output_chars`
- `daily_story_limit`
- `ip_rate_per_min`, `uid_rate_per_min`
- `max_body_kb`
- `request_timeout_ms`

> For local testing you can set `POLICY_MODE=static` and provide `POLICY_STATIC_JSON`, but production should use Firestore.

## Strict request/response validation

All request schemas are `.strict()` and allowlisted:

- `storyLang`: `ru | en | hy`
- `ageGroup`: `3_5 | 6_8 | 9_12`
- `storyLength`: `short | medium | long`

Unknown fields cause `400 Invalid request`.

## Two-stage moderation

Requests go through:

1) input moderation (before Vertex)
2) output moderation (after Vertex)

On moderation failure, the service:

- does **not** write `stories/*`
- writes only `story_audit/*`
- returns a **safe stub** story (200) with headers `X-KidsTel-Blocked: 1` and `X-KidsTel-Block-Reason: ...`

## curl examples

> Replace `<ID_TOKEN>` and `<APPCHECK_TOKEN>`.

### Missing Authorization (expect 401 when `AUTH_REQUIRED=true`)

```bash
curl -sS -D - "$STORY_AGENT_URL" \
	-H "Content-Type: application/json" \
	-H "X-Firebase-AppCheck: <APPCHECK_TOKEN>" \
	-d '{"action":"generate","storyLang":"en","selection":{"hero":"Cat"}}'
```

### Missing App Check (expect 403 when `APPCHECK_REQUIRED=true`)

```bash
curl -sS -D - "$STORY_AGENT_URL" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer <ID_TOKEN>" \
	-d '{"action":"generate","storyLang":"en","selection":{"hero":"Cat"}}'
```

### Generate (backward-compatible `/`)

```bash
curl -sS "$STORY_AGENT_URL" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer <ID_TOKEN>" \
	-H "X-Firebase-AppCheck: <APPCHECK_TOKEN>" \
	-d '{
		"action": "generate",
		"storyLang": "en",
		"ageGroup": "3_5",
		"storyLength": "medium",
		"creativityLevel": 0.5,
		"image": {"enabled": false},
		"selection": {"hero": "Cat", "location": "Park", "style": "Adventure"}
	}'
```

### Generate (empty input) -> 422 `generate_input_required`

Note: depending on your deployment, you may need `Authorization` and `X-Firebase-AppCheck` headers.

```bash
curl -sS "$STORY_AGENT_URL" \
	-H "Content-Type: application/json" \
	-d '{"action":"generate","storyLang":"en"}'
```

Expected:
- HTTP 422
- JSON body includes `{"error":"generate_input_required"}` (plus `requestId` and `debug`)

### Invalid JSON body -> 400 `invalid_json`

```bash
curl -sS "$STORY_AGENT_URL" \
	-H "Content-Type: application/json" \
	-d '{'
```

Expected:
- HTTP 400
- JSON body includes `{"error":"invalid_json"}` (plus `requestId` and `debug`)

### Continue

```bash
curl -sS "$STORY_AGENT_URL" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer <ID_TOKEN>" \
	-H "X-Firebase-AppCheck: <APPCHECK_TOKEN>" \
	-d '{
		"action": "continue",
		"storyId": "<STORY_ID>",
		"choice": {"id": "c1", "payload": {}},
		"storyLang": "en"
	}'
```

### Illustrate (never 501)

```bash
curl -sS "$STORY_AGENT_URL/v1/story/illustrate" \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer <ID_TOKEN>" \
	-H "X-Firebase-AppCheck: <APPCHECK_TOKEN>" \
	-d '{
		"storyId": "<STORY_ID>",
		"storyLang": "en",
		"prompt": "A friendly cat in a sunny park"
	}'
```

If illustrations are disabled by policy, you still get HTTP 200 with a placeholder `image.base64` and the response will be marked as disabled.

### Quota / rate limit (expect 429)

The service can return HTTP 429 either due to:
- per-minute rate limits (IP/UID)
- daily Firestore quota (`usage_daily`)

In both cases the response body is a safe JSON error, and quota/rate controls should be tuned via `admin_policy/runtime`.

## Local dev

1) Ensure you have Google Cloud ADC credentials (for Vertex AI + Firestore):

```bash
gcloud auth application-default login
```

2) Copy env:

```bash
cp .env.example .env
```

3) Install/build/run:

```bash
npm install
npm run build
npm start
```

## Cloud Run deploy (outline)

You will need:

- Vertex AI API enabled
- Firestore enabled
- Cloud Run service account with:
	- Vertex AI User (or equivalent)
	- Firestore access (Datastore User or more specific)

Example deploy:

```bash
gcloud run deploy kidstell-story-agent \
	--source . \
	--region us-central1 \
	--allow-unauthenticated \
	--set-env-vars GOOGLE_CLOUD_PROJECT=kids-tell-d0ks8m,VERTEX_LOCATION=us-central1,GEMINI_MODEL=gemini-1.5-flash,AUTH_REQUIRED=true,APPCHECK_REQUIRED=true
```

> Note: even with `--allow-unauthenticated`, the service itself can require tokens via `AUTH_REQUIRED`/`APPCHECK_REQUIRED`.
