import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { randomUUID } from 'crypto';
import type { Request, Response } from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ZodError } from 'zod';

import { readEnv } from './env.js';
import { httpLogger, logger } from './logging.js';
import { getAdminApp, getFirestore } from './firebase.js';
import { verifyRequestTokens } from './auth.js';
import { moderateText } from './moderation.js';
import {
  AgentResponseSchema,
  CreateRequestSchema,
  ContinueRequestSchema,
  IllustrationResponseSchema,
  IllustrateRequestSchema,
  LangSchema,
} from './storySchemas.js';
import { generateContinueResponse, generateCreateResponse } from './storyEngine.js';
import {
  enforceDailyLimit as enforceDailyLimitDefault,
  upsertStorySession as upsertStorySessionDefault,
  writeAudit as writeAuditDefault,
} from './firestoreStore.js';
import { createPolicyLoader } from './policy.js';
import { isAppError, toSafeErrorBody, AppError } from './errors.js';

function yyyymmdd(d: Date) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}${m}${day}`;
}

function getLangOrDefault(raw: unknown): 'ru' | 'en' | 'hy' {
  const v = raw?.toString().trim().toLowerCase();
  const parsed = LangSchema.safeParse(v);
  return parsed.success ? parsed.data : 'en';
}

function safeStubResponse(opts: {
  requestId: string;
  storyId: string;
  lang: 'ru' | 'en' | 'hy';
  chapterIndex: number;
}) {
  const msg =
    opts.lang === 'ru'
      ? 'Давай попробуем другую идею. Я могу рассказать добрую историю, если ты изменишь запрос.'
      : opts.lang === 'hy'
        ? 'Փորձենք մեկ այլ գաղափար։ Ես կարող եմ պատմել բարի պատմություն, եթե փոխես հարցումը։'
        : "Let's try a different idea. I can tell a kind story if you change the request.";

  const title =
    opts.lang === 'ru'
      ? 'Попробуем иначе'
      : opts.lang === 'hy'
        ? 'Փորձենք այլ կերպ'
        : "Let's try again";

  return AgentResponseSchema.parse({
    requestId: opts.requestId,
    storyId: opts.storyId,
    chapterIndex: opts.chapterIndex,
    progress: 1,
    title,
    text: msg,
    image: { enabled: false, url: null },
    choices: [],
  });
}

export function createApp(
  processEnv: NodeJS.ProcessEnv = process.env,
  deps?: {
    firestore?: any;
    store?: {
      enforceDailyLimit?: typeof enforceDailyLimitDefault;
      upsertStorySession?: typeof upsertStorySessionDefault;
      writeAudit?: typeof writeAuditDefault;
    };
  },
) {
  const env = readEnv(processEnv);
  const needsFirestore = env.policyMode === 'firestore' || !env.storeDisabled;
  const fs = (deps?.firestore ?? (needsFirestore ? getFirestore(env.projectId, env.firestoreDatabaseId) : null)) as any;

  const store = {
    enforceDailyLimit: deps?.store?.enforceDailyLimit ?? enforceDailyLimitDefault,
    upsertStorySession: deps?.store?.upsertStorySession ?? upsertStorySessionDefault,
    writeAudit: deps?.store?.writeAudit ?? writeAuditDefault,
  };
  const policyLoader = createPolicyLoader({
    firestore: (fs ?? ({} as any)) as any,
    ttlMs: 60_000,
    mode: env.policyMode,
    staticJson: env.policyStaticJson,
  });

  // Lazily initialize firebase-admin only if a request requires token verification.
  const getAdminAppLazy = () => getAdminApp(env.projectId);

  // Per-UID/IP per-minute limiters (per instance).
  const uidBuckets = new Map<string, { resetAt: number; count: number }>();
  const ipBuckets = new Map<string, { resetAt: number; count: number }>();

  function takeUidQuota(uid: string, limitPerMin: number): boolean {
    const now = Date.now();
    const bucket = uidBuckets.get(uid);
    if (!bucket || bucket.resetAt <= now) {
      uidBuckets.set(uid, { resetAt: now + 60_000, count: 1 });
      return true;
    }
    if (bucket.count >= limitPerMin) return false;
    bucket.count += 1;
    return true;
  }

  function takeIpQuota(ip: string, limitPerMin: number): boolean {
    const now = Date.now();
    const bucket = ipBuckets.get(ip);
    if (!bucket || bucket.resetAt <= now) {
      ipBuckets.set(ip, { resetAt: now + 60_000, count: 1 });
      return true;
    }
    if (bucket.count >= limitPerMin) return false;
    bucket.count += 1;
    return true;
  }

  async function getPolicyOrFailClosed() {
    const policy = await policyLoader.getPolicy();
    if (!policy) {
      throw new AppError({
        status: 503,
        code: 'POLICY_UNAVAILABLE',
        safeMessage: 'Service temporarily disabled',
      });
    }
    return policy;
  }

  async function requireAuth(req: Request, res: Response): Promise<{ uid: string } | null> {
    try {
      const auth = await verifyRequestTokens({
        req,
        getAdminApp: getAdminAppLazy,
        authRequired: env.authRequired,
        appCheckRequired: env.appCheckRequired,
      });
      return auth ? { uid: auth.uid } : null;
    } catch (e) {
      if (isAppError(e)) {
        res.status(e.status).json(toSafeErrorBody(e));
        return null;
      }
      res.status(401).json({ error: 'Unauthorized' });
      return null;
    }
  }

  const app = express();
  app.set('trust proxy', 1);
  app.use(httpLogger);
  app.use(
    helmet({
      contentSecurityPolicy: false,
    }),
  );
  app.use(
    cors({
      origin: false,
    }),
  );

  // Coarse hard cap (policy may tighten).
  app.use(express.json({ limit: '64kb' }));

  // Coarse IP rate limit per instance.
  app.use(
    rateLimit({
      windowMs: 60_000,
      limit: 120,
      standardHeaders: true,
      legacyHeaders: false,
    }),
  );

  app.get('/healthz', (_req, res) => res.status(200).json({ ok: true }));

  async function handleCreate(req: Request, res: Response, route: string) {
    if (env.killSwitch) return res.status(503).json({ error: 'Service temporarily disabled' });

    try {
      const auth = await requireAuth(req, res);
      if (!auth) return;

      const policy = await getPolicyOrFailClosed();
      if (!policy.enable_story_generation) {
        await store.writeAudit(fs as any, {
          requestId: `req_${randomUUID()}`,
          uid: auth.uid,
          route,
          blocked: true,
          blockReason: 'generation_disabled',
        }).catch(() => undefined);
        return res.status(503).json({ error: 'Service temporarily disabled' });
      }

      const ip = (req.ip || req.socket?.remoteAddress || 'unknown').toString();
      if (!takeIpQuota(ip, policy.ip_rate_per_min)) return res.status(429).json({ error: 'Too many requests' });
      if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) return res.status(429).json({ error: 'Too many requests' });

      const contentLen = Number(req.headers['content-length'] ?? '0');
      if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
        return res.status(413).json({ error: 'Request entity too large' });
      }

      const body = CreateRequestSchema.parse(req.body ?? {});
      const lang = getLangOrDefault(body.storyLang);
      const model = policy.model_allowlist.includes(env.geminiModel) ? env.geminiModel : policy.model_allowlist[0];

      if (!env.storeDisabled) {
        if (!fs) throw new AppError({ status: 503, code: 'STORE_UNAVAILABLE', safeMessage: 'Service temporarily disabled' });
        try {
          await store.enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
        } catch (e: any) {
          if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
            const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
            await store
              .writeAudit(fs as any, {
                requestId,
                uid: auth.uid,
                route,
                blocked: true,
                blockReason: 'daily_limit_exceeded',
              })
              .catch(() => undefined);
            return res.status(429).json({ error: 'Daily limit exceeded' });
          }
          throw e;
        }
      }

      const combinedInput = JSON.stringify({
        idea: body.idea ?? '',
        hero: body.selection?.hero ?? '',
        location: body.selection?.location ?? '',
        storyType: body.selection?.style ?? '',
      });

      const mod = moderateText(combinedInput, policy.max_input_chars);
      if (!mod.allowed) {
        const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
        if (!env.storeDisabled) {
          await store.writeAudit(fs as any, {
            requestId,
            uid: auth.uid,
            route,
            blocked: true,
            blockReason: `moderation_input:${mod.reason}`,
          }).catch(() => undefined);
        }

        res.setHeader('X-KidsTel-Blocked', '1');
        res.setHeader('X-KidsTel-Block-Reason', 'moderation_input');
        return res.status(200).json(
          safeStubResponse({ requestId, storyId: `story_${randomUUID()}`, lang, chapterIndex: 0 }),
        );
      }

      const out = await generateCreateResponse({
        projectId: env.projectId,
        vertexLocation: env.vertexLocation,
        geminiModel: model,
        uid: auth.uid,
        request: {
          requestId: body.requestId,
          ageGroup: body.ageGroup,
          storyLang: body.storyLang,
          storyLength: body.storyLength,
          creativityLevel: body.creativityLevel,
          imageEnabled: body.image?.enabled ?? false,
          hero: body.selection?.hero,
          location: body.selection?.location,
          storyType: body.selection?.style,
          idea: body.idea,
        },
        generation: { maxOutputTokens: policy.max_output_tokens, temperature: policy.temperature },
        requestTimeoutMs: policy.request_timeout_ms,
        mock: env.mockEngine,
      });

      const modOut = moderateText(`${out.title}\n${out.text}`, policy.max_output_chars);
      if (!modOut.allowed) {
        if (!env.storeDisabled) {
          await store.writeAudit(fs as any, {
            requestId: out.requestId,
            uid: auth.uid,
            route,
            blocked: true,
            blockReason: `moderation_output:${modOut.reason}`,
            storyId: out.storyId,
          }).catch(() => undefined);
        }

        res.setHeader('X-KidsTel-Blocked', '1');
        res.setHeader('X-KidsTel-Block-Reason', 'moderation_output');
        return res.status(200).json(
          safeStubResponse({ requestId: out.requestId, storyId: out.storyId, lang, chapterIndex: 0 }),
        );
      }

      if (!env.storeDisabled) {
        if (!fs) throw new AppError({ status: 503, code: 'STORE_UNAVAILABLE', safeMessage: 'Service temporarily disabled' });
        await store.upsertStorySession(fs as any, {
          storyId: out.storyId,
          uid: auth.uid,
          title: out.title,
          chapters: [
            {
              chapterIndex: out.chapterIndex,
              title: out.title,
              text: out.text,
              progress: out.progress,
              imageUrl: out.image?.url ?? null,
              choices: (out.choices ?? []).map((c: any) => ({ id: c.id, label: c.label, payload: c.payload ?? {} })),
            },
          ],
        });

        await store.writeAudit(fs as any, {
          requestId: out.requestId,
          uid: auth.uid,
          route,
          blocked: false,
          storyId: out.storyId,
        }).catch(() => undefined);
      }

      return res.status(200).json(out);
    } catch (e: any) {
      if (e instanceof ZodError) return res.status(400).json({ error: 'Invalid request' });
      if (isAppError(e)) return res.status(e.status).json(toSafeErrorBody(e));
      logger.error({ err: e }, 'create failed');
      return res.status(500).json({ error: 'Internal error' });
    }
  }

  async function handleContinue(req: Request, res: Response, route: string) {
    if (env.killSwitch) return res.status(503).json({ error: 'Service temporarily disabled' });

    try {
      const auth = await requireAuth(req, res);
      if (!auth) return;

      const policy = await getPolicyOrFailClosed();
      if (!policy.enable_story_generation) {
        await store.writeAudit(fs as any, {
          requestId: `req_${randomUUID()}`,
          uid: auth.uid,
          route,
          blocked: true,
          blockReason: 'generation_disabled',
        }).catch(() => undefined);
        return res.status(503).json({ error: 'Service temporarily disabled' });
      }

      const ip = (req.ip || req.socket?.remoteAddress || 'unknown').toString();
      if (!takeIpQuota(ip, policy.ip_rate_per_min)) return res.status(429).json({ error: 'Too many requests' });
      if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) return res.status(429).json({ error: 'Too many requests' });

      const contentLen = Number(req.headers['content-length'] ?? '0');
      if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
        return res.status(413).json({ error: 'Request entity too large' });
      }

      const body = ContinueRequestSchema.parse(req.body ?? {});
      const lang = getLangOrDefault(body.storyLang);
      const model = policy.model_allowlist.includes(env.geminiModel) ? env.geminiModel : policy.model_allowlist[0];

      if (env.storeDisabled) {
        // Continue requires stored story context.
        return res.status(503).json({ error: 'Service temporarily disabled' });
      }
      if (!fs) throw new AppError({ status: 503, code: 'STORE_UNAVAILABLE', safeMessage: 'Service temporarily disabled' });

      try {
        await store.enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
      } catch (e: any) {
        if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
          const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
          await store
            .writeAudit(fs as any, {
              requestId,
              uid: auth.uid,
              route,
              blocked: true,
              blockReason: 'daily_limit_exceeded',
              storyId: body.storyId,
            })
            .catch(() => undefined);
          return res.status(429).json({ error: 'Daily limit exceeded' });
        }
        throw e;
      }

      const snap = await fs.collection('stories').doc(body.storyId).get();
      if (!snap.exists) return res.status(404).json({ error: 'Story not found' });
      const data = snap.data() as any;
      if (data?.uid !== auth.uid) return res.status(403).json({ error: 'Forbidden' });

      const chapters = Array.isArray(data?.chapters) ? data.chapters : [];
      const last = chapters.length ? chapters[chapters.length - 1] : null;
      const prevText = (last?.text ?? '').toString();

      const combinedInput = JSON.stringify({
        choice: body.choice ?? {},
        hero: body.selection?.hero ?? '',
        location: body.selection?.location ?? '',
        storyType: body.selection?.style ?? '',
      });

      const mod = moderateText(combinedInput, policy.max_input_chars);
      if (!mod.allowed) {
        const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
        await store.writeAudit(fs as any, {
          requestId,
          uid: auth.uid,
          route,
          blocked: true,
          blockReason: `moderation_input:${mod.reason}`,
          storyId: body.storyId,
        }).catch(() => undefined);

        res.setHeader('X-KidsTel-Blocked', '1');
        res.setHeader('X-KidsTel-Block-Reason', 'moderation_input');
        return res.status(200).json(
          safeStubResponse({
            requestId,
            storyId: body.storyId,
            lang,
            chapterIndex: (last?.chapterIndex ?? body.chapterIndex ?? 0) + 1,
          }),
        );
      }

      const out = await generateContinueResponse({
        projectId: env.projectId,
        vertexLocation: env.vertexLocation,
        geminiModel: model,
        uid: auth.uid,
        previousText: prevText,
        request: {
          requestId: body.requestId,
          storyId: body.storyId,
          chapterIndex: last?.chapterIndex ?? body.chapterIndex ?? 0,
          choice: body.choice ?? {},
          ageGroup: body.ageGroup,
          storyLang: body.storyLang,
          storyLength: body.storyLength,
          hero: body.selection?.hero,
          location: body.selection?.location,
          storyType: body.selection?.style,
        },
        generation: { maxOutputTokens: policy.max_output_tokens, temperature: policy.temperature },
        requestTimeoutMs: policy.request_timeout_ms,
        mock: env.mockEngine,
      });

      const modOut = moderateText(`${out.title}\n${out.text}`, policy.max_output_chars);
      if (!modOut.allowed) {
        await store.writeAudit(fs as any, {
          requestId: out.requestId,
          uid: auth.uid,
          route,
          blocked: true,
          blockReason: `moderation_output:${modOut.reason}`,
          storyId: out.storyId,
        }).catch(() => undefined);

        res.setHeader('X-KidsTel-Blocked', '1');
        res.setHeader('X-KidsTel-Block-Reason', 'moderation_output');
        return res.status(200).json(
          safeStubResponse({ requestId: out.requestId, storyId: out.storyId, lang, chapterIndex: out.chapterIndex }),
        );
      }

      const nextChapters = chapters.concat([
        {
          chapterIndex: out.chapterIndex,
          title: out.title,
          text: out.text,
          progress: out.progress,
          imageUrl: out.image?.url ?? null,
          choices: (out.choices ?? []).map((c: any) => ({ id: c.id, label: c.label, payload: c.payload ?? {} })),
        },
      ]);

      await store.upsertStorySession(fs as any, {
        storyId: out.storyId,
        uid: auth.uid,
        title: data?.title ?? out.title,
        chapters: nextChapters,
      });

      await store.writeAudit(fs as any, {
        requestId: out.requestId,
        uid: auth.uid,
        route,
        blocked: false,
        storyId: out.storyId,
      }).catch(() => undefined);

      return res.status(200).json(out);
    } catch (e: any) {
      if (e instanceof ZodError) return res.status(400).json({ error: 'Invalid request' });
      if (isAppError(e)) return res.status(e.status).json(toSafeErrorBody(e));
      logger.error({ err: e }, 'continue failed');
      return res.status(500).json({ error: 'Internal error' });
    }
  }

  async function handleIllustrate(req: Request, res: Response, route: string) {
    if (env.killSwitch) return res.status(503).json({ error: 'Service temporarily disabled' });

    try {
      const auth = await requireAuth(req, res);
      if (!auth) return;

      const policy = await getPolicyOrFailClosed();

      const ip = (req.ip || req.socket?.remoteAddress || 'unknown').toString();
      if (!takeIpQuota(ip, policy.ip_rate_per_min)) return res.status(429).json({ error: 'Too many requests' });
      if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) return res.status(429).json({ error: 'Too many requests' });

      const contentLen = Number(req.headers['content-length'] ?? '0');
      if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
        return res.status(413).json({ error: 'Request entity too large' });
      }

      const body = IllustrateRequestSchema.parse(req.body ?? {});

      if (!env.storeDisabled) {
        if (!fs) throw new AppError({ status: 503, code: 'STORE_UNAVAILABLE', safeMessage: 'Service temporarily disabled' });
        try {
          await store.enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
        } catch (e: any) {
          if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
            const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
            await store
              .writeAudit(fs as any, {
                requestId,
                uid: auth.uid,
                route,
                blocked: true,
                blockReason: 'daily_limit_exceeded',
                storyId: body.storyId,
              })
              .catch(() => undefined);
            return res.status(429).json({ error: 'Daily limit exceeded' });
          }
          throw e;
        }
      }

      // 1x1 transparent PNG.
      const base64 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/xcAAwMCAO9pN1cAAAAASUVORK5CYII=';

      if (!policy.enable_illustrations) {
        const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
        if (!env.storeDisabled) {
          await store.writeAudit(fs as any, {
            requestId,
            uid: auth.uid,
            route,
            blocked: true,
            blockReason: 'illustrations_disabled',
            storyId: body.storyId,
          }).catch(() => undefined);
        }

        return res.status(200).json(
          IllustrationResponseSchema.parse({
            disabled: true,
            reason: 'Illustrations are disabled by policy',
            image: { base64 },
          }),
        );
      }

      // Still no 501: placeholder until a real image backend is wired.
      const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
      if (!env.storeDisabled) {
        await store.writeAudit(fs as any, {
          requestId,
          uid: auth.uid,
          route,
          blocked: false,
          storyId: body.storyId,
        }).catch(() => undefined);
      }

      return res.status(200).json(
        IllustrationResponseSchema.parse({
          disabled: false,
          reason: 'Illustration generation is not configured yet',
          image: { base64 },
        }),
      );
    } catch (e: any) {
      logger.error({ err: e }, 'illustrate failed');
      if (e instanceof ZodError) return res.status(400).json({ error: 'Invalid request' });
      if (isAppError(e)) return res.status(e.status).json(toSafeErrorBody(e));

      // Still avoid 501.
      return res.status(200).json(
        IllustrationResponseSchema.parse({
          disabled: true,
          reason: 'Illustrations unavailable',
          image: {
            base64:
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/xcAAwMCAO9pN1cAAAAASUVORK5CYII=',
          },
        }),
      );
    }
  }

  // Backward-compatible endpoint
  app.post('/', async (req, res) => {
    const action = (req.body?.action ?? '').toString().trim().toLowerCase();
    if (action === 'generate') return handleCreate(req, res, '/');
    if (action === 'continue') return handleContinue(req, res, '/');
    if (action === 'illustrate') return handleIllustrate(req, res, '/');
    return res.status(400).json({ error: 'Unsupported action' });
  });

  app.post('/v1/story/create', async (req, res) => handleCreate(req, res, '/v1/story/create'));
  app.post('/v1/story/continue', async (req, res) => handleContinue(req, res, '/v1/story/continue'));
  app.post('/v1/story/illustrate', async (req, res) => handleIllustrate(req, res, '/v1/story/illustrate'));

  return { app, env };
}

const isMain = path.resolve(process.argv[1] ?? '') === fileURLToPath(import.meta.url);
if (isMain) {
  const { app, env } = createApp(process.env);
  app.listen(env.port, () => {
    logger.info({ port: env.port }, 'KidsTel story agent listening');
  });
}

/*
LEGACY (disabled): The file previously contained an older server bootstrap below.
It is kept commented-out to avoid duplicate declarations.

const app = express();
app.use(httpLogger);
app.use(helmet({
  // API-only service
  contentSecurityPolicy: false,
}));
app.use(cors({
  origin: false, // mobile app only; keep closed by default
}));

// Hard body cap (also enforced per-policy later via content-length).
app.use(express.json({ limit: '64kb' }));

// Basic IP rate limit (per instance). Policy can further tighten per-request.
app.use(rateLimit({
  windowMs: 60_000,
  limit: 120,
  standardHeaders: true,
  legacyHeaders: false,
}));

// Request timeout guard (per instance default); policy can tighten.
app.use((req, res, next) => {
  const timer = setTimeout(() => {
    if (!res.headersSent) {
      res.status(504).json({ error: 'Request timeout' });
    }
  }, 25_000);
  res.on('finish', () => clearTimeout(timer));
  res.on('close', () => clearTimeout(timer));
  next();
});

app.get('/healthz', (_req: Request, res: Response) => {
  res.status(200).json({ ok: true });
});

function yyyymmdd(d: Date) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}${m}${day}`;
}

async function takeQuotaOrFail(uid: string, res: Response): Promise<boolean> {
  try {
    await enforceDailyLimit(fs as any, {
      uid,
      limit: env.dailyStoryLimit,
      yyyymmdd: yyyymmdd(new Date()),
    });
    return true;
  } catch (e: any) {
    if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
      res.status(429).json({ error: 'Daily limit exceeded' });
      return false;
    }
    throw e;
  }
}

async function requireAuth(req: Request, res: Response): Promise<{ uid: string } | null> {
  try {
    const auth = await verifyRequestTokens({
      req, 
      adminApp,
      authRequired: env.authRequired,
      appCheckRequired: env.appCheckRequired,
    });
    return auth ? { uid: auth.uid } : null;
  } catch (e) {
    if (isAppError(e)) {
      res.status(e.status).json(toSafeErrorBody(e));
      return null;
    }
    res.status(401).json({ error: 'Unauthorized' });
    return null;
  }
}

// Per-UID per-minute limiter (per instance). Combined with Firestore daily limit.
const uidBuckets = new Map<string, { resetAt: number; count: number }>();
function takeUidQuota(uid: string, limitPerMin: number): boolean {
  const now = Date.now();
  const bucket = uidBuckets.get(uid);
  if (!bucket || bucket.resetAt <= now) {
    uidBuckets.set(uid, { resetAt: now + 60_000, count: 1 });
    return true;
  }
  if (bucket.count >= limitPerMin) return false;
  bucket.count += 1;
  return true;
}

function safeStubResponse(opts: {
  requestId: string;
  storyId: string;
  lang: 'ru' | 'en' | 'hy';
  chapterIndex: number;
  reasonCode?: string; // Made optional
}) {
  const msg =
    opts.lang === 'ru'
      ? 'Давай попробуем другую идею. Я могу рассказать добрую историю, если ты изменишь запрос.'
      : opts.lang === 'hy'
        ? 'Փորձենք մեկ այլ գաղափար։ Ես կարող եմ պատմել բարի պատմություն, եթե փոխես հարցումը։'
        : 'Let\'s try a different idea. I can tell a kind story if you change the request.';

  const title =
    opts.lang === 'ru'
      ? 'Попробуем иначе'
      : opts.lang === 'hy'
        ? 'Փորձենք այլ կերպ'
        : 'Let\'s try again';

  const resp = {
    requestId: opts.requestId,
    storyId: opts.storyId,
    chapterIndex: opts.chapterIndex,
    progress: 1,
    title,
    text: msg,
    image: { enabled: false, url: null },
    choices: [],
  };
  return AgentResponseSchema.parse(resp);
}

async function getPolicyOrFailClosed(res: Response) {
  const policy = await policyLoader.getPolicy();
  if (!policy) {
    throw new AppError({
      status: 503,
      code: 'POLICY_UNAVAILABLE',
      safeMessage: 'Service temporarily disabled',
    });
  }
  return policy;
}

function getLangOrDefault(raw: unknown): 'ru' | 'en' | 'hy' {
  const v = raw?.toString().trim().toLowerCase();
  const parsed = LangSchema.safeParse(v);
  return parsed.success ? parsed.data : 'en';
}

async function handleCreate(req: Request, res: Response, route: string) {
  if (env.killSwitch) return res.status(503).json({ error: 'Service temporarily disabled' });

  try {
    const auth = await requireAuth(req, res);
    if (!auth) return;

    const policy = await getPolicyOrFailClosed(res);
    if (!policy.enable_story_generation) {
      await writeAudit(fs as any, {
        requestId: `req_${randomUUID()}`,
        uid: auth.uid,
        route,
        blocked: true,
        blockReason: 'generation_disabled',
      }).catch(() => undefined);
      return res.status(503).json({ error: 'Service temporarily disabled' });
    }

    // Policy-based request timeout (tighten default)
    res.setTimeout(policy.request_timeout_ms);

    // Policy-based body limit (fail closed)
    const contentLen = Number(req.headers['content-length'] ?? '0');
    if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
      return res.status(413).json({ error: 'Request entity too large' });
    }

    // UID rate limit (per instance)
    if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) {
      return res.status(429).json({ error: 'Too many requests' });
    }

    // Daily limit
    try {
      await enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
    } catch (e: any) {
      if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
        return res.status(429).json({ error: 'Daily limit exceeded' });
      }
      throw e;
    }

    const body = CreateRequestSchema.parse(req.body ?? {});

    // Model allowlist & parameters
    const model = policy.model_allowlist.includes(env.geminiModel) ? env.geminiModel : policy.model_allowlist[0];

    const lang = getLangOrDefault(body.storyLang);

    // Stage 1 moderation (input)
    const combinedInput = JSON.stringify({
      idea: body.idea ?? '',
      hero: body.selection?.hero ?? '',
      location: body.selection?.location ?? '',
      storyType: body.selection?.style ?? '',
    });

    const mod = moderateText(combinedInput, policy.max_input_chars);
    if (!mod.allowed) {
      const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
      await writeAudit(fs as any, {
        requestId,
        uid: auth.uid,
        route,
        blocked: true,
        blockReason: `moderation_input:${mod.reason}`,
      }).catch(() => undefined);

      // Safe stub + audit only (no stories write)
      res.setHeader('X-KidsTel-Blocked', '1');
      res.setHeader('X-KidsTel-Block-Reason', 'moderation_input');
      return res.status(200).json(
        safeStubResponse({
          requestId,
          storyId: `story_${randomUUID()}`,
          lang,
          chapterIndex: 0,
          reasonCode: 'moderation_input',
        }),
      );
    }

    const out = await generateCreateResponse({
      projectId: env.projectId,
      vertexLocation: env.vertexLocation,
      geminiModel: model,
      uid: auth.uid,
      request: {
        requestId: body.requestId,
        ageGroup: body.ageGroup,
        storyLang: body.storyLang,
        storyLength: body.storyLength,
        creativityLevel: body.creativityLevel,
        imageEnabled: body.image?.enabled ?? false,
        hero: body.selection?.hero,
        location: body.selection?.location,
        storyType: body.selection?.style,
        idea: body.idea,
      },
      generation: {
        maxOutputTokens: policy.max_output_tokens,
        temperature: policy.temperature,
      },
      mock: env.mockEngine,
    });

    // Stage 2 moderation (output)
    const modOut = moderateText(`${out.title}\n${out.text}`, policy.max_output_chars);
    if (!modOut.allowed) {
      await writeAudit(fs as any, {
        requestId: out.requestId,
        uid: auth.uid,
        route,
        blocked: true,
        blockReason: `moderation_output:${modOut.reason}`,
        storyId: out.storyId,
      }).catch(() => undefined);

      // Do not persist stories on output fail
      res.setHeader('X-KidsTel-Blocked', '1');
      res.setHeader('X-KidsTel-Block-Reason', 'moderation_output');
      return res.status(200).json(
        safeStubResponse({
          requestId: out.requestId,
          storyId: out.storyId,
          lang,
          chapterIndex: 0,
          reasonCode: 'moderation_output',
        }),
      );
    }

    await upsertStorySession(fs as any, {
      storyId: out.storyId,
      uid: auth.uid,
      title: out.title,
      chapters: [
        {
          chapterIndex: out.chapterIndex,
          title: out.title,
          text: out.text,
          progress: out.progress,
          imageUrl: out.image?.url ?? null,
          choices: (out.choices ?? []).map((c: any) => ({ id: c.id, label: c.label, payload: c.payload ?? {} })),
        },
      ],
    });

    await writeAudit(fs as any, {
      requestId: out.requestId,
      uid: auth.uid,
      route,
      blocked: false,
      storyId: out.storyId,
    });

    return res.status(200).json(out);
  } catch (e: any) {
    if (isAppError(e)) {
      return res.status(e.status).json(toSafeErrorBody(e));
    }
    logger.error({ err: e }, 'create failed');
    return res.status(500).json({ error: 'Internal error' });
  }
}

async function handleContinue(req: Request, res: Response, route: string) {
  if (env.killSwitch) return res.status(503).json({ error: 'Service temporarily disabled' });

  try {
    const auth = await requireAuth(req, res);
    if (!auth) return;

    const policy = await getPolicyOrFailClosed(res);
    if (!policy.enable_story_generation) {
      await writeAudit(fs as any, {
        requestId: `req_${randomUUID()}`,
        uid: auth.uid,
        route,
        blocked: true,
        blockReason: 'generation_disabled',
      }).catch(() => undefined);
      return res.status(503).json({ error: 'Service temporarily disabled' });
    }

    res.setTimeout(policy.request_timeout_ms);
    const contentLen = Number(req.headers['content-length'] ?? '0');
    if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
      return res.status(413).json({ error: 'Request entity too large' });
    }
    if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) {
      return res.status(429).json({ error: 'Too many requests' });
    }

    try {
      await enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
    } catch (e: any) {
      if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
        return res.status(429).json({ error: 'Daily limit exceeded' });
      }
      throw e;
    }

    const body = ContinueRequestSchema.parse(req.body ?? {});

    const lang = getLangOrDefault(body.storyLang);
    const model = policy.model_allowlist.includes(env.geminiModel) ? env.geminiModel : policy.model_allowlist[0];

    const snap = await fs.collection('stories').doc(body.storyId).get();
    if (!snap.exists) {
      return res.status(404).json({ error: 'Story not found' });
    }
    const data = snap.data() as any;
    if (data?.uid !== auth.uid) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const chapters = Array.isArray(data?.chapters) ? data.chapters : [];
    const last = chapters.length ? chapters[chapters.length - 1] : null;
    const prevText = (last?.text ?? '').toString();

    const combinedInput = JSON.stringify({
      choice: body.choice ?? {},
      hero: body.selection?.hero ?? '',
      location: body.selection?.location ?? '',
      storyType: body.selection?.style ?? '',
    });

    const mod = moderateText(combinedInput, policy.max_input_chars);
    if (!mod.allowed) {
      const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
      await writeAudit(fs as any, {
        requestId,
        uid: auth.uid,
        route,
        blocked: true,
        blockReason: `moderation_input:${mod.reason}`,
        storyId: body.storyId,
      }).catch(() => undefined);

      res.setHeader('X-KidsTel-Blocked', '1');
      res.setHeader('X-KidsTel-Block-Reason', 'moderation_input');
      return res.status(200).json(
        safeStubResponse({
          requestId,
          storyId: body.storyId,
          lang,
          chapterIndex: (last?.chapterIndex ?? body.chapterIndex ?? 0) + 1,
          reasonCode: 'moderation_input',
        }),
      );
    }

    const out = await generateContinueResponse({
      projectId: env.projectId,
      vertexLocation: env.vertexLocation,
      geminiModel: model,
      uid: auth.uid,
      previousText: prevText,
      request: {
        requestId: body.requestId,
        storyId: body.storyId,
        chapterIndex: last?.chapterIndex ?? body.chapterIndex ?? 0,
        choice: body.choice ?? {},
        ageGroup: body.ageGroup,
        storyLang: body.storyLang,
        storyLength: body.storyLength,
        hero: body.selection?.hero,
        location: body.selection?.location,
        storyType: body.selection?.style,
      },
      generation: {
        maxOutputTokens: policy.max_output_tokens,
        temperature: policy.temperature,
      },
      mock: env.mockEngine,
    });

    const modOut = moderateText(`${out.title}\n${out.text}`, policy.max_output_chars);
    if (!modOut.allowed) {
      await writeAudit(fs as any, {
        requestId: out.requestId,
        uid: auth.uid,
        route,
        blocked: true,
        blockReason: `moderation_output:${modOut.reason}`,
        storyId: out.storyId,
      }).catch(() => undefined);

      res.setHeader('X-KidsTel-Blocked', '1');
      res.setHeader('X-KidsTel-Block-Reason', 'moderation_output');
      return res.status(200).json(
        safeStubResponse({
          requestId: out.requestId,
          storyId: out.storyId,
          lang,
          chapterIndex: out.chapterIndex,
          reasonCode: 'moderation_output',
        }),
      );
    }

    const nextChapters = chapters.concat([
      {
        chapterIndex: out.chapterIndex,
        title: out.title,
        text: out.text,
        progress: out.progress,
        imageUrl: out.image?.url ?? null,
        choices: (out.choices ?? []).map((c: any) => ({ id: c.id, label: c.label, payload: c.payload ?? {} })),
      },
    ]);

    await upsertStorySession(fs as any, {
      storyId: out.storyId,
      uid: auth.uid,
      title: data?.title ?? out.title,
      chapters: nextChapters,
    });

    await writeAudit(fs as any, {
      requestId: out.requestId,
      uid: auth.uid,
      route,
      blocked: false,
      storyId: out.storyId,
    });

    return res.status(200).json(out);
  } catch (e: any) {
    if (isAppError(e)) {
      return res.status(e.status).json(toSafeErrorBody(e));
    }
    logger.error({ err: e }, 'continue failed');
    return res.status(500).json({ error: 'Internal error' });
  }
}

async function handleIllustrate(req: Request, res: Response, route: string) {
  if (env.killSwitch) return res.status(503).json({ error: 'Service temporarily disabled' });

  // For production readiness we guarantee: no 501.
  // Illustrations are OFF by default; if the client calls anyway, we return a
  // deterministic placeholder image (transparent PNG) so the app does not crash.

  try {
    const auth = await requireAuth(req, res);
    if (!auth) return;

    const policy = await getPolicyOrFailClosed(res);
    res.setTimeout(policy.request_timeout_ms);

    const contentLen = Number(req.headers['content-length'] ?? '0');
    if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
      return res.status(413).json({ error: 'Request entity too large' });
    }
    if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) {
      return res.status(429).json({ error: 'Too many requests' });
    }

    // Daily limit (illustrations count too, intentionally)
    try {
      await enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
    } catch (e: any) {
      if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
        return res.status(429).json({ error: 'Daily limit exceeded' });
      }
      throw e;
    }

    // Validate request shape strictly
    const body = IllustrateRequestSchema.parse(req.body ?? {});

    if (!policy.enable_illustrations) {
      const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
      await writeAudit(fs as any, {
        requestId,
        uid: auth.uid,
        route,
        blocked: true,
        blockReason: 'illustrations_disabled',
        storyId: body.storyId,
      }).catch(() => undefined);

      const resp = IllustrationResponseSchema.parse({
        disabled: true,
        reason: 'Illustrations are disabled by policy',
        image: {
          base64:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/xcAAwMCAO9pN1cAAAAASUVORK5CYII=',
        },
      });

      return res.status(200).json(resp);
    }

    // 1x1 transparent PNG.
    const base64 =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/xcAAwMCAO9pN1cAAAAASUVORK5CYII=';

    // Placeholder implementation for now (still no 501). When enabled,
    // you can swap this to a real image generation backend.
    const requestId = body.requestId?.trim() || `req_${randomUUID()}`;
    await writeAudit(fs as any, {
      requestId,
      uid: auth.uid,
      route,
      blocked: false,
      storyId: body.storyId,
    }).catch(() => undefined);

    const resp = IllustrationResponseSchema.parse({
      disabled: false,
      reason: 'Illustration generation is not configured yet',
      image: { base64 },
    });
    return res.status(200).json(resp);
  } catch (e: any) {
    logger.error({ err: e }, 'illustrate failed');
    if (isAppError(e)) {
      return res.status(e.status).json(toSafeErrorBody(e));
    }
    return res.status(200).json(
      IllustrationResponseSchema.parse({
        disabled: true,
        reason: 'Illustrations unavailable',
        image: {
          base64:
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/xcAAwMCAO9pN1cAAAAASUVORK5CYII=',
        },
      }),
    );
  }
}

// Backward-compatible single endpoint: Flutter currently posts to STORY_AGENT_URL
// with an {action: 'generate'|'continue'|'illustrate', ...} JSON body.
app.post('/', async (req: Request, res: Response) => {
  const action = (req.body?.action ?? '').toString().trim().toLowerCase();
  if (action === 'generate') return handleCreate(req, res, '/');
  if (action === 'continue') return handleContinue(req, res, '/');
  if (action === 'illustrate') return handleIllustrate(req, res, '/');
  return res.status(400).json({ error: 'Unsupported action', action });
});

app.post('/v1/story/create', async (req: Request, res: Response) => handleCreate(req, res, '/v1/story/create'));
app.post('/v1/story/continue', async (req: Request, res: Response) => handleContinue(req, res, '/v1/story/continue'));
app.post('/v1/story/illustrate', async (req: Request, res: Response) => handleIllustrate(req, res, '/v1/story/illustrate'));

export { app };

app.listen(env.port, () => {
  logger.info({ port: env.port }, 'KidsTel story agent listening');
});

*/
