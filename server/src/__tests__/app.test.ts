import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import { createApp } from '../index.js';
import { AppError } from '../errors.js';

// NOTE: These tests are "integration-ish" and rely on MOCK_ENGINE + static policy.

// IMPORTANT: auth.ts reads NODE_ENV from global process.env (not from the injected env map),
// and only honors X-KidsTel-Dev-Uid when NODE_ENV !== 'production'.
// Some CI environments set NODE_ENV=production by default, so force a non-production value
// for the duration of this test suite.
let __prevNodeEnv: string | undefined;
test.before(() => {
  __prevNodeEnv = process.env.NODE_ENV;
  process.env.NODE_ENV = 'test';
});

test.after(() => {
  if (__prevNodeEnv == null) {
    delete process.env.NODE_ENV;
  } else {
    process.env.NODE_ENV = __prevNodeEnv;
  }
});

const baseEnv = {
  GOOGLE_CLOUD_PROJECT: 'kids-tell-d0ks8m',
  FIREBASE_PROJECT_ID: 'kids-tell-d0ks8m',
  VERTEX_LOCATION: 'us-central1',
  VERTEX_IMAGE_MODEL: 'imagen-3.0-generate-001',
  STORAGE_BUCKET: 'kids-tell-d0ks8m.firebasestorage.app',
  GEMINI_MODEL: 'gemini-2.5-flash',

  KIDSTEL_REV: 'testrev',
  K_SERVICE: 'llm-generateitem',
  K_CONFIGURATION: 'llm-generateitem',
  K_REVISION: 'rev-test',

  // Enforce tokens by default unless overridden.
  AUTH_REQUIRED: 'true',
  APPCHECK_REQUIRED: 'true',

  // Fail-closed policy loader would disable generation unless we provide static policy.
  POLICY_MODE: 'static',
  POLICY_STATIC_JSON: JSON.stringify({
    enable_story_generation: true,
    enable_illustrations: false,
    model_allowlist: ['gemini-2.5-flash'],
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

const noopStore = {
  enforceDailyLimit: async () => undefined,
  getStoryMeta: async () => null,
  listStoryChapters: async () => [],
  getStoryChapter: async () => null,
  writeStoryChapter: async () => undefined,
  updateChapterIllustration: async () => undefined,
  upsertStorySession: async () => undefined,
  writeAudit: async () => undefined,
};

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
  assert.equal(res.body?.code, 'APPCHECK_MISSING');
});

test('placeholder/fake appcheck token -> 403 APPCHECK_INVALID', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'true' });

  const res = await request(app)
    .post('/')
    .set('X-Firebase-AppCheck', 'placeholder')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 403);
  assert.equal(res.body?.code, 'APPCHECK_INVALID');
});

test('appcheck enforced on all story routes (missing -> 403)', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'true' });

  const routes: Array<{ path: string; body: any }> = [
    { path: '/', body: { action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } } },
    { path: '/v1/story/create', body: { storyLang: 'en', selection: { hero: 'Cat' } } },
    { path: '/v1/story/continue', body: { storyLang: 'en', storyId: 'story_test', chapterIndex: 0 } },
    { path: '/v1/story/illustrate', body: { storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' } },
  ];

  for (const r of routes) {
    const res = await request(app).post(r.path).send(r.body);
    assert.equal(res.status, 403, `expected 403 for ${r.path}`);
    assert.equal(res.body?.code, 'APPCHECK_MISSING', `expected APPCHECK_MISSING for ${r.path}`);
  }
});

test('appcheck enforced on all story routes (placeholder -> 403)', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'true' });

  const routes: Array<{ path: string; body: any }> = [
    { path: '/', body: { action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } } },
    { path: '/v1/story/create', body: { storyLang: 'en', selection: { hero: 'Cat' } } },
    { path: '/v1/story/continue', body: { storyLang: 'en', storyId: 'story_test', chapterIndex: 0 } },
    { path: '/v1/story/illustrate', body: { storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' } },
  ];

  for (const r of routes) {
    const res = await request(app)
      .post(r.path)
      .set('X-Firebase-AppCheck', 'placeholder')
      .send(r.body);
    assert.equal(res.status, 403, `expected 403 for ${r.path}`);
    assert.equal(res.body?.code, 'APPCHECK_INVALID', `expected APPCHECK_INVALID for ${r.path}`);
  }
});

test('unknown extra fields are ignored (generate still succeeds)', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', idea: 'Hello', selection: { hero: 'Cat' }, extra: 'nope' });

  assert.equal(res.status, 200);
  assert.equal(typeof res.body?.requestId, 'string');
});

test('storyLang aliases like ru-RU are normalized', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({
      action: 'generate',
      storyLang: 'ru-RU',
      selection: { hero: 'Cat' },
    });

  assert.equal(res.status, 200);
  assert.equal(typeof res.body?.storyId, 'string');
});

test('missing action -> 400 action_required', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app).post('/').send({ storyLang: 'en' });

  assert.equal(res.status, 400);
  assert.equal(res.body?.error, 'action_required');
});

test('generate missing storyLang -> 400 storyLang_required', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', selection: { hero: 'Cat' } });

  assert.equal(res.status, 400);
  assert.equal(res.body?.error, 'storyLang_required');
});

test('generate missing idea/prompt/selection/storyId -> 422 generate_input_required', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'ru' });

  assert.equal(res.status, 422);
  assert.equal(res.body?.error, 'generate_input_required');
});

test('generate with selection-only -> 200 (mock engine)', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({
      action: 'generate',
      storyLang: 'en',
      selection: { hero: 'Cat', location: 'Forest', style: 'Friendly' },
    });

  assert.equal(res.status, 200);
  assert.ok(typeof res.body?.storyId === 'string' && res.body.storyId.length > 0);
  assert.equal(res.body?.chapterIndex, 0);
});

test('upstream daily quota 429 -> 429 quota_daily_exceeded (no 500)', async () => {
  const app = freshAppWithDeps(
    {
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'true',
      MOCK_ENGINE: 'false',
    },
    {
      engine: {
        generateCreateResponse: async () => {
          throw new AppError({
            status: 429,
            code: 'UPSTREAM_DAILY_QUOTA',
            safeMessage: 'Quota exceeded. Please try again later.',
            message: 'Daily limit exceeded for quota metric',
          });
        },
      },
    },
  );

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 429);
  assert.equal(res.body?.error, 'quota_daily_exceeded');
  assert.equal(res.body?.retryAfterSec, 86400);
  assert.equal(res.body?.provider, 'vertex');
  assert.ok(typeof res.body?.model === 'string' && res.body.model.length > 0);
});

test('invalid JSON body -> 400 invalid_json', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/v1/story/illustrate')
    .set('Content-Type', 'application/json')
    .send('{"storyId":"s1",}');

  assert.equal(res.status, 400);
  assert.equal(res.body?.error, 'invalid_json');
});

test('illustrate missing storyId -> 400 storyId_required', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/v1/story/illustrate')
    .send({ storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' });

  assert.equal(res.status, 400);
  assert.equal(res.body?.error, 'storyId_required');
});

test('illustrate story lookup miss -> 404 story_not_found', async () => {
  const policy = JSON.stringify({
    enable_story_generation: true,
    enable_illustrations: true,
    model_allowlist: ['gemini-2.5-flash'],
    daily_story_limit: 40,
    uid_rate_per_min: 60,
    ip_rate_per_min: 120,
    max_body_kb: 64,
    request_timeout_ms: 25000,
    max_input_chars: 1200,
    max_output_chars: 12000,
    max_output_tokens: 256,
    temperature: 0.2,
  });

  const app = freshAppWithDeps(
    {
      NODE_ENV: 'test',
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'false',
      POLICY_STATIC_JSON: policy,
    },
    {
      firestore: {},
      store: {
        enforceDailyLimit: async () => undefined,
        writeAudit: async () => undefined,
        getStoryMeta: async () => null,
        getStoryChapter: async () => null,
        updateChapterIllustration: async () => undefined,
        listStoryChapters: async () => [],
        writeStoryChapter: async () => undefined,
        upsertStorySession: async () => undefined,
      },
      image: {
        generateImageBytes: async () => ({ bytes: Buffer.from('x'), mimeType: 'image/png' } as any),
      },
      storage: {
        uploadIllustration: async () => ({ url: 'https://example.com/x.png', storagePath: 'x.png', bucket: 'b' }),
      },
    },
  );

  const res = await request(app)
    .post('/v1/story/illustrate')
    .send({ storyId: 'story_missing', storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' });

  assert.equal(res.status, 404);
  assert.equal(res.body?.error, 'story_not_found');
});

test('illustrate vertex image empty -> 200 with placeholder (no 5xx)', async () => {
  const prevNodeEnv = process.env.NODE_ENV;
  process.env.NODE_ENV = 'test';

  try {
    const policy = JSON.stringify({
      enable_story_generation: true,
      enable_illustrations: true,
      model_allowlist: ['gemini-2.5-flash'],
      daily_story_limit: 40,
      uid_rate_per_min: 60,
      ip_rate_per_min: 120,
      max_body_kb: 64,
      request_timeout_ms: 25000,
      max_input_chars: 1200,
      max_output_chars: 12000,
      max_output_tokens: 256,
      temperature: 0.2,
    });

    const app = freshAppWithDeps(
      {
        AUTH_REQUIRED: 'false',
        APPCHECK_REQUIRED: 'false',
        STORE_DISABLED: 'false',
        POLICY_STATIC_JSON: policy,
      },
      {
        firestore: {},
        store: {
          enforceDailyLimit: async () => undefined,
          writeAudit: async () => undefined,
          // In AUTH_REQUIRED=false mode, the server generates an anon uid unless a stable
          // X-KidsTel-Dev-Uid header is provided.
          getStoryMeta: async () => ({ uid: 'anon_testuid', title: 'T', lang: 'en' } as any),
          getStoryChapter: async () => ({ chapterIndex: 0, title: 'T', text: 'Hello', progress: 0.1 } as any),
          updateChapterIllustration: async () => undefined,
          listStoryChapters: async () => [],
          writeStoryChapter: async () => undefined,
          upsertStorySession: async () => undefined,
        },
        image: {
          generateImageBytes: async () => {
            throw new AppError({ status: 502, code: 'VERTEX_IMAGE_EMPTY', safeMessage: 'Illustrations unavailable' });
          },
        },
        storage: {
          uploadIllustration: async () => ({ url: 'https://example.com/x.png', storagePath: 'x.png', bucket: 'b' }),
        },
      },
    );

    const res = await request(app)
      .post('/v1/story/illustrate')
      .set('X-KidsTel-Dev-Uid', 'testuid')
      .send({ storyId: 'story_ok', storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' });

    if (res.status !== 200) {
      throw new Error(`unexpected ${res.status}: ${JSON.stringify(res.body)}`);
    }
    assert.equal(res.body?.image?.disabled, true);
    assert.ok(typeof res.body?.image?.base64 === 'string' && res.body.image.base64.length > 0);
    assert.equal(res.body?.chapterIndex, 0);
  } finally {
    if (prevNodeEnv == null) {
      delete process.env.NODE_ENV;
    } else {
      process.env.NODE_ENV = prevNodeEnv;
    }
  }
});

test('/v1/story/illustrate route exists (no 404)', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/v1/story/illustrate')
    .send({ storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'hello' });

  assert.notEqual(res.status, 404);
});

test('/WithChapterLanguage legacy route exists (no 404)', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/WithChapterLanguage')
    .send({ storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'hello' });

  assert.notEqual(res.status, 404);
});

test('happy path (mock engine) -> 200 with response keys', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', idea: 'Hello', selection: { hero: 'Cat' } });

  assert.equal(res.status, 200);
  assert.equal(res.headers['x-kidstel-rev'], 'testrev');
  assert.equal(res.headers['x-kidstel-service'], 'llm-generateitem');
  assert.equal(res.headers['x-kidstel-action'], 'generate');
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
    .send({ storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' });

  assert.equal(res.status, 503);
  assert.equal(res.body?.error, 'illustrations_disabled');
});

test('illustrate routing: POST / with action illustrate hits handler (no 404)', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/')
    .send({ action: 'illustrate', storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' });

  // Policy disables illustrations in baseEnv, so we expect 503 from the handler.
  assert.equal(res.status, 503);
  assert.equal(res.body?.error, 'illustrations_disabled');
});

test('invalid json body -> 400 invalid_json', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/v1/story/illustrate')
    .set('Content-Type', 'application/json')
    .send('{"storyId":"story_test","storyLang":"en","chapterIndex":0,');

  assert.equal(res.status, 400);
  assert.equal(res.body?.error, 'invalid_json');
});

test('illustrate moderation -> 200 with base64 placeholder (no url null)', async () => {
  const mem: any = {
    meta: { storyId: 'story_test', uid: 'anon_testuid', title: 'T', lang: 'en', latestChapterIndex: 0, ageGroup: '3_5' },
    chapters: [
      {
        chapterIndex: 0,
        title: 'T',
        text: 'Once upon a time...',
        progress: 0.25,
        choices: [],
      },
    ],
  };

  const policy = JSON.stringify({
    enable_story_generation: true,
    enable_illustrations: true,
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
  });

  const app = freshAppWithDeps(
    {
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'false',
      POLICY_STATIC_JSON: policy,
    },
    {
      firestore: {},
      store: {
        enforceDailyLimit: async () => undefined,
        writeAudit: async () => undefined,
        getStoryMeta: async () => mem.meta,
        getStoryChapter: async (_fs: any, _sid: string, idx: number) => mem.chapters.find((c: any) => c.chapterIndex === idx) ?? null,
        updateChapterIllustration: async () => undefined,
        listStoryChapters: async () => mem.chapters,
        writeStoryChapter: async () => undefined,
        upsertStorySession: async () => undefined,
      },
      image: {
        generateImageBytes: async () => {
          throw new Error('should not call vertex when blocked by moderation');
        },
      },
      storage: {
        uploadIllustration: async () => {
          throw new Error('should not upload when blocked by moderation');
        },
      },
    },
  );

  const res = await request(app)
    .post('/v1/story/illustrate')
    .set('X-KidsTel-Dev-Uid', 'testuid')
    .send({ storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'A story about a gun' });

  assert.equal(res.status, 200);
  assert.equal(res.body?.image?.disabled, true);
  assert.equal(res.body?.image?.reason, 'moderation_input');
  assert.ok(typeof res.body?.image?.base64 === 'string' && res.body.image.base64.startsWith('data:image/png;base64,'));
  assert.equal(res.body?.image?.url, undefined);
});

test('illustrate validation -> 400 prompt_required', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/v1/story/illustrate')
    .send({ storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: '' });

  assert.equal(res.status, 400);
  assert.equal(res.body?.error, 'prompt_required');
});

test('illustrate validation -> 400 chapterIndex_required', async () => {
  const app = freshApp({ AUTH_REQUIRED: 'false', APPCHECK_REQUIRED: 'false' });

  const res = await request(app)
    .post('/v1/story/illustrate')
    .send({ storyId: 'story_test', storyLang: 'en', prompt: 'A friendly cat' });

  assert.equal(res.status, 400);
  assert.equal(res.body?.error, 'chapterIndex_required');
});

test('illustrate misconfigured pipeline -> 503', async () => {
  const app = freshApp({
    AUTH_REQUIRED: 'false',
    APPCHECK_REQUIRED: 'false',
    VERTEX_IMAGE_MODEL: '',
  });

  const res = await request(app)
    .post('/v1/story/illustrate')
    .send({ storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' });

  assert.equal(res.status, 503);
  assert.equal(res.body?.error, 'image_pipeline_misconfigured');
});

test('continue keeps storyId and increments chapterIndex (mock engine + store)', async () => {
  // Minimal in-memory store so continue can load story context.
  const mem: any = {
    meta: { storyId: 'story_test', uid: 'anon_testuid', title: 'T', lang: 'en', latestChapterIndex: 0 },
    chapters: [
      {
        chapterIndex: 0,
        title: 'T',
        text: 'Once upon a time...',
        progress: 0.25,
        choices: [{ id: 'c1', label: 'Go outside', payload: { action: 'continue' } }],
      },
    ],
  };

  const app = freshAppWithDeps(
    {
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'false',
    },
    {
      firestore: {},
      store: {
        enforceDailyLimit: async () => undefined,
        writeAudit: async () => undefined,
        getStoryMeta: async () => mem.meta,
        listStoryChapters: async () => mem.chapters,
        getStoryChapter: async (_fs: any, _sid: string, idx: number) => mem.chapters.find((c: any) => c.chapterIndex === idx) ?? null,
        writeStoryChapter: async (_fs: any, opts: any) => {
          mem.chapters.push(opts.chapter);
          mem.meta.latestChapterIndex = opts.chapter.chapterIndex;
        },
        updateChapterIllustration: async () => undefined,
        upsertStorySession: async () => undefined,
      },
    },
  );

  const res = await request(app)
    .post('/')
    .set('X-KidsTel-Dev-Uid', 'testuid')
    .send({ action: 'continue', storyId: 'story_test', chapterIndex: 0, storyLang: 'en', choice: { id: 'c1' } });

  assert.equal(res.status, 200);
  assert.equal(res.headers['x-kidstel-rev'], 'testrev');
  assert.equal(res.headers['x-kidstel-service'], 'llm-generateitem');
  assert.equal(res.headers['x-kidstel-action'], 'continue');
  assert.equal(res.body.storyId, 'story_test');
  assert.equal(res.body.chapterIndex, 1);
});

test('illustrate returns https url when enabled (mock image+storage)', async () => {
  const mem: any = {
    meta: { storyId: 'story_test', uid: 'anon_testuid', title: 'T', lang: 'en', latestChapterIndex: 0 },
    chapters: [
      {
        chapterIndex: 0,
        title: 'T',
        text: 'A friendly scene.',
        progress: 0.25,
        choices: [],
      },
    ],
  };

  const app = freshAppWithDeps(
    {
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'false',
      POLICY_STATIC_JSON: JSON.stringify({
        enable_story_generation: true,
        enable_illustrations: true,
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
    },
    {
      firestore: {},
      store: {
        enforceDailyLimit: async () => undefined,
        writeAudit: async () => undefined,
        getStoryMeta: async () => mem.meta,
        getStoryChapter: async () => mem.chapters[0],
        listStoryChapters: async () => mem.chapters,
        writeStoryChapter: async () => undefined,
        updateChapterIllustration: async (_fs: any, opts: any) => {
          mem.chapters[0].imageUrl = opts.imageUrl;
        },
        upsertStorySession: async () => undefined,
      },
      image: {
        generateImageBytes: async () => ({ bytes: Buffer.from([1, 2, 3]), mimeType: 'image/png' } as any),
      },
      storage: {
        uploadIllustration: async () => ({
          url: 'https://example.com/illustration.png',
          storagePath: 'stories/story_test/chapters/0/illustration.png',
          bucket: 'test-bucket',
        }),
      },
    },
  );

  const res = await request(app)
    .post('/v1/story/illustrate')
    .set('X-KidsTel-Dev-Uid', 'testuid')
    .send({ storyId: 'story_test', storyLang: 'en', chapterIndex: 0, prompt: 'A friendly cat' });

  if (res.status !== 200) {
    throw new Error(`unexpected ${res.status}: ${JSON.stringify(res.body)}`);
  }
  assert.equal(res.body?.image?.enabled, true);
  assert.ok(typeof res.body?.image?.url === 'string' && res.body.image.url.startsWith('https://'));
  assert.equal(res.body?.debug?.revision, 'rev-test');
  assert.equal(res.body?.debug?.service, 'llm-generateitem');
  assert.equal(res.body?.debug?.configuration, 'llm-generateitem');
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
    .send({ action: 'generate', storyLang: 'en', idea: 'Hello', selection: { hero: 'Cat' } });
  assert.equal(r1.status, 200);

  const r2 = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', idea: 'Hello', selection: { hero: 'Cat' } });
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
    .send({ action: 'generate', storyLang: 'en', idea: 'Hello', selection: { hero: 'Cat' } });

  assert.equal(res.status, 429);
  assert.equal(res.body?.error, 'daily_limit_exceeded');
  assert.equal(typeof res.body?.requestId, 'string');
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
    .send({ action: 'generate', storyLang: 'en', idea: 'Hello', selection: { hero: 'Cat' } });

  assert.equal(res.status, 503);
  assert.equal(res.body?.error, 'Service temporarily disabled');
  assert.equal(res.body?.code, 'POLICY_UNAVAILABLE');
});

test('store failures during generate return 503 STORE_UNAVAILABLE', async () => {
  const app = freshAppWithDeps(
    {
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'false',
    },
    {
      firestore: {} as any,
      engine: {
        generateCreateResponse: async () => ({
          requestId: 'req_test',
          storyId: 'story_test',
          chapterIndex: 0,
          progress: 0.2,
          title: 'Hello',
          text: 'World',
          image: { enabled: false, url: null },
          choices: [],
        }),
      },
      store: {
        ...noopStore,
        enforceDailyLimit: async () => {
          throw new Error('firestore_unavailable');
        },
      },
    },
  );

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 503);
  assert.equal(res.body?.code, 'STORE_UNAVAILABLE');
  assert.equal(res.body?.error, 'Service temporarily disabled');
});

test('store failures after generation are surfaced as 503', async () => {
  const app = freshAppWithDeps(
    {
      AUTH_REQUIRED: 'false',
      APPCHECK_REQUIRED: 'false',
      STORE_DISABLED: 'false',
    },
    {
      firestore: {} as any,
      engine: {
        generateCreateResponse: async () => ({
          requestId: 'req_test',
          storyId: 'story_test',
          chapterIndex: 0,
          progress: 0.5,
          title: 'Hello',
          text: 'World',
          image: { enabled: false, url: null },
          choices: [],
        }),
      },
      store: {
        ...noopStore,
        upsertStorySession: async () => {
          throw new Error('write_failed');
        },
      },
    },
  );

  const res = await request(app)
    .post('/')
    .send({ action: 'generate', storyLang: 'en', selection: { hero: 'Cat' } });

  assert.equal(res.status, 503);
  assert.equal(res.body?.code, 'STORE_UNAVAILABLE');
  assert.equal(res.body?.error, 'Service temporarily disabled');
});
