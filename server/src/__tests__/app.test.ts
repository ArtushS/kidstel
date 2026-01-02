import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../index.js';

// NOTE: These tests are "integration-ish" and rely on MOCK_ENGINE + static policy.

const baseEnv = {
  GOOGLE_CLOUD_PROJECT: 'kids-tell-d0ks8m',
  FIREBASE_PROJECT_ID: 'kids-tell-d0ks8m',
  VERTEX_LOCATION: 'us-central1',
  GEMINI_MODEL: 'gemini-1.5-flash',

  // Enforce tokens by default unless overridden.
  AUTH_REQUIRED: 'true',
  APPCHECK_REQUIRED: 'true',

  // Fail-closed policy loader would disable generation unless we provide static policy.
  POLICY_MODE: 'static',
  POLICY_STATIC_JSON: JSON.stringify({
    enable_story_generation: true,
    enable_illustrations: false,
    model_allowlist: ['gemini-1.5-flash'],
    daily_story_limit: 40,
    uid_rate_per_min: 60,
    ip_rate_per_min: 120,
    max_body_kb: 64,
    request_timeout_ms: 25000,
    max_input_chars: 1200,
    max_output_chars: 12000,
    max_output_tokens: 256,
    temperature: 0.2,
  }),

  MOCK_ENGINE: 'true',
  STORE_DISABLED: 'true',
};

function freshApp(envOverrides: Record<string, string>) {
  const merged = { ...process.env, ...baseEnv, ...envOverrides } as any;
  return createApp(merged).app as any;
}

function freshAppWithDeps(
  envOverrides: Record<string, string>,
  deps: Parameters<typeof createApp>[1],
) {
  const merged = { ...process.env, ...baseEnv, ...envOverrides } as any;
  return createApp(merged, deps).app as any;
}

test('missing auth token -> 401', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'true', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 401);
});

test('missing appcheck token -> 403', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'true' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 403);
});

test('strict schema rejects unknown fields -> 400', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' }, extra: 'nope' });

  assert.equal(res.status, 400);
});

test('happy path (mock engine) -> 200 with response keys', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 200);
  assert.ok(res.body);
  assert.equal(typeof res.body.requestId, 'string');
  assert.equal(typeof res.body.storyId, 'string');
  assert.equal(typeof res.body.title, 'string');
  assert.equal(typeof res.body.text, 'string');
});

test('illustrate returns 200 and never 501', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/v1/story/illustrate')
    .send({ storyId: 'story_test', storyLang: 'en', prompt: 'A friendly cat' });

  assert.equal(res.status, 200);
  assert.ok(res.body.image);
});

test('moderation blocked -> 200 safe stub + headers', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', idea: 'A story about a gun' });

  assert.equal(res.status, 200);
  assert.equal(res.headers['x-kidstel-blocked'], '1');
  assert.equal(res.headers['x-kidstel-block-reason'], 'moderation_input');
  assert.equal(typeof res.body.text, 'string');
});

test('rate limit (uid/ip) -> 429', async () => {
  const tightPolicy = JSON.stringify({
    enable_story_generation: true,
    enable_illustrations: false,
    model_allowlist: ['gemini-1.5-flash'],
    daily_story_limit: 40,
    uid_rate_per_min: 1,
    ip_rate_per_min: 1,
    max_body_kb: 64,
    request_timeout_ms: 25000,
    max_input_chars: 1200,
    max_output_chars: 12000,
    max_output_tokens: 128,
    temperature: 0.2,
  });

  const app = freshApp({
    AUTH_REQUIRED: 'false',
    APPCHECK_REQUIRED: 'false',
    POLICY_STATIC_JSON: tightPolicy,
  });

  const r1 = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });
  assert.equal(r1.status, 200);

  const r2 = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });
  assert.equal(r2.status, 429);
});

test('daily limit exceeded -> 429 + audit record', async () => {
  const audits: any[] = [];

  const app = freshAppWithDeps(
    {
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'false',
    },
    {
      firestore: {},
      store: {
        enforceDailyLimit: async () => {
          throw new Error('DAILY_LIMIT_EXCEEDED');
        },
        upsertStorySession: async () => undefined,
        writeAudit: async (_fs: any, rec: any) => {
          audits.push(rec);
        },
      },
    },
  );

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 429);
  assert.equal(res.body?.error, 'Daily limit exceeded');
  assert.equal(audits.length, 1);
  assert.equal(audits[0].blocked, true);
  assert.equal(audits[0].blockReason, 'daily_limit_exceeded');
});

test('policy loader firestore error -> fail-closed (503)', async () => {
  const app = freshAppWithDeps(
    {
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'true',
      POLICY_MODE: 'firestore',
      POLICY_STATIC_JSON: '',
    },
    {
      firestore: {
        collection: () => {
          throw new Error('firestore_down');
        },
      },
    },
  );

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 503);
  assert.equal(res.body?.error, 'Service temporarily disabled');
  assert.equal(res.body?.code, 'POLICY_UNAVAILABLE');
});
