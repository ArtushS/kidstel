import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { randomUUID } from 'crypto';
import type { Request, Response, NextFunction } from 'express';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ZodError } from 'zod';

import { readEnv } from './env.js';
import { httpLogger, logger } from './logging.js';
import { getAdminApp, getFirestore, getStorageBucket } from './firebase.js';
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
  getStoryChapter as getStoryChapterDefault,
  getStoryMeta as getStoryMetaDefault,
  listStoryChapters as listStoryChaptersDefault,
  updateChapterIllustration as updateChapterIllustrationDefault,
  upsertStorySession as upsertStorySessionDefault,
  writeStoryChapter as writeStoryChapterDefault,
  writeAudit as writeAuditDefault,
} from './firestoreStore.js';
import { createPolicyLoader } from './policy.js';
import { isAppError, toSafeErrorBody, AppError } from './errors.js';
import { generateImageWithVertex } from './vertexImage.js';
import { buildUniversalImageSystemPrompt, TRANSPARENT_1X1_PNG_DATA_URL, IMAGE_PROMPT_DEFAULTS } from './imagePrompt.js';
import type { ImageAspectRatio, ImageSize } from './imagePrompt.js';

function yyyymmdd(d: Date) {
  const y = d.getUTCFullYear();
  const m = String(d.getUTCMonth() + 1).padStart(2, '0');
  const day = String(d.getUTCDate()).padStart(2, '0');
  return `${y}${m}${day}`;
}

function newRequestId() {
  return `req_${randomUUID()}`;
}

function respondError(
  res: Response,
  status: number,
  code: string,
  extra?: Record<string, unknown>,
) {
  const localsRid = (res.locals as any)?.requestId;
  const requestId =
    typeof (extra as any)?.requestId === 'string' && ((extra as any).requestId as string).trim()
      ? (((extra as any).requestId as string).trim() as string)
      : typeof localsRid === 'string' && localsRid.trim()
        ? localsRid.trim()
        : newRequestId();

  const body: Record<string, unknown> = { error: code, requestId };
  if (extra && typeof extra === 'object') {
    for (const [k, v] of Object.entries(extra)) {
      if (k === 'requestId') continue;
      body[k] = v;
    }
  }
  return res.status(status).json(body);
}

function looksLikeNonEmptyString(v: unknown): v is string {
  return typeof v === 'string' && v.trim().length > 0;
}

function selectionHasAnyInput(v: unknown): boolean {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return false;
  const o = v as any;
  return [o.hero, o.location, o.style].some((x) => typeof x === 'string' && x.trim().length > 0);
}

function safeSortedKeys(v: unknown): string[] {
  if (!v || typeof v !== 'object' || Array.isArray(v)) return [];
  return Object.keys(v as any)
    .map((k) => String(k))
    .sort();
}

function safeTextLen(v: unknown): number {
  return typeof v === 'string' ? v.trim().length : 0;
}

function normalizeLangInput(raw: unknown): 'ru' | 'en' | 'hy' | undefined {
  const v = raw?.toString().trim().toLowerCase();
  if (!v) return undefined;
  const parsed = LangSchema.safeParse(v);
  if (parsed.success) return parsed.data;

  const compact = v.replace(/[_-]/g, '');
  if (compact.startsWith('ru')) return 'ru';
  if (compact.startsWith('en')) return 'en';
  if (compact.startsWith('hy') || compact.startsWith('am')) return 'hy';

  return undefined;
}

function getLangOrDefault(raw: unknown): 'ru' | 'en' | 'hy' {
  const normalized = normalizeLangInput(raw);
  const v = normalized ?? raw?.toString().trim().toLowerCase();
  const parsed = LangSchema.safeParse(v);
  return parsed.success ? parsed.data : 'en';
}

function isVertexModelNotFoundError(e: unknown): boolean {
  // VertexAI ClientError for retired/unknown models is typically a 404 NOT_FOUND.
  const msg = String((e as any)?.message ?? '');
  return msg.includes('got status: 404') && msg.includes('Publisher Model') && msg.includes('was not found');
}

function toUpstreamErrorMessageShort(e: unknown): string | undefined {
  const msg = String((e as any)?.message ?? '').trim();
  if (!msg) return undefined;
  return msg
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s\s+/g, ' ')
    .trim()
    .slice(0, 240);
}

function upstreamStatusFromError(e: unknown): number | undefined {
  const msg = String((e as any)?.message ?? '');
  const m = msg.match(/got status:\s*(\d{3})/i);
  const statusFromMsg = m ? Number(m[1]) : NaN;
  const status = Number.isFinite(statusFromMsg)
    ? statusFromMsg
    : typeof (e as any)?.status === 'number'
      ? (e as any).status
      : typeof (e as any)?.code === 'number'
        ? (e as any).code
        : undefined;
  return typeof status === 'number' && Number.isFinite(status) ? status : undefined;
}

function upstreamServiceFromMessage(msg: string): string | undefined {
  const m = msg.toLowerCase();
  if (m.includes('aiplatform.googleapis.com') || m.includes('vertex')) return 'aiplatform.googleapis.com';
  if (m.includes('generativelanguage.googleapis.com')) return 'generativelanguage.googleapis.com';
  return undefined;
}

function isUpstreamDailyQuotaExceeded(e: unknown): boolean {
  // Preferred signal: normalized AppError from storyEngine.ts
  if (isAppError(e) && e.status === 429 && e.code === 'UPSTREAM_DAILY_QUOTA') return true;

  // Fallback: heuristics if error shape changes.
  const status = upstreamStatusFromError(e);
  if (status !== 429) return false;
  const msg = String((e as any)?.message ?? '');
  return /daily limit exceeded/i.test(msg) || /(quota|limit).*(per day|daily)/i.test(msg);
}

async function callWithGeminiModelFallback<T>(
  models: string[],
  fn: (model: string) => Promise<T>,
): Promise<{ out: T; usedModel: string }> {
  let lastErr: unknown;
  for (const m of models) {
    const model = (m ?? '').toString().trim();
    if (!model) continue;
    try {
      const out = await fn(model);
      return { out, usedModel: model };
    } catch (e) {
      // Attach for higher-level logging/response shaping.
      try {
        (e as any).attemptedModel = model;
      } catch (_) {
        // ignore
      }
      lastErr = e;
      if (isVertexModelNotFoundError(e)) {
        logger.warn({ model, err: e }, 'gemini model not found; trying fallback');
        continue;
      }
      throw e;
    }
  }
  throw new AppError({
    status: 503,
    code: 'MODEL_UNAVAILABLE',
    safeMessage: 'Model unavailable',
    message: String((lastErr as any)?.message ?? lastErr ?? ''),
  });
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
    engine?: {
      generateCreateResponse?: typeof generateCreateResponse;
      generateContinueResponse?: typeof generateContinueResponse;
    };
    store?: {
      enforceDailyLimit?: typeof enforceDailyLimitDefault;
      getStoryMeta?: typeof getStoryMetaDefault;
      listStoryChapters?: typeof listStoryChaptersDefault;
      getStoryChapter?: typeof getStoryChapterDefault;
      writeStoryChapter?: typeof writeStoryChapterDefault;
      updateChapterIllustration?: typeof updateChapterIllustrationDefault;
      upsertStorySession?: typeof upsertStorySessionDefault;
      writeAudit?: typeof writeAuditDefault;
    };
    image?: {
      generateImageBytes?: typeof generateImageWithVertex;
    };
    storage?: {
      // Upload image bytes and return a usable https URL.
      uploadIllustration?: (opts: {
        storyId: string;
        chapterIndex: number;
        bytes: Buffer;
        contentType: string;
        lang: string;
        signedUrlDays: number;
      }) => Promise<{ url: string; storagePath: string; bucket: string }>;
    };
  },
) {
  const env = readEnv(processEnv);
  const serverRevision = (processEnv.KIDSTEL_REV || processEnv.GIT_SHA || processEnv.SOURCE_VERSION || 'dev').toString();
  const serverServiceName = (processEnv.K_SERVICE || 'kidstell-story-agent').toString();
  const needsFirestore = env.policyMode === 'firestore' || !env.storeDisabled;
  const fs = (deps?.firestore ?? (needsFirestore ? getFirestore(env.projectId, env.firestoreDatabaseId) : null)) as any;

  const store = {
    enforceDailyLimit: deps?.store?.enforceDailyLimit ?? enforceDailyLimitDefault,
    getStoryMeta: deps?.store?.getStoryMeta ?? getStoryMetaDefault,
    listStoryChapters: deps?.store?.listStoryChapters ?? listStoryChaptersDefault,
    getStoryChapter: deps?.store?.getStoryChapter ?? getStoryChapterDefault,
    writeStoryChapter: deps?.store?.writeStoryChapter ?? writeStoryChapterDefault,
    updateChapterIllustration: deps?.store?.updateChapterIllustration ?? updateChapterIllustrationDefault,
    upsertStorySession: deps?.store?.upsertStorySession ?? upsertStorySessionDefault,
    writeAudit: deps?.store?.writeAudit ?? writeAuditDefault,
  };

  const image = {
    generateImageBytes: deps?.image?.generateImageBytes ?? generateImageWithVertex,
  };

  const engine = {
    generateCreateResponse: deps?.engine?.generateCreateResponse ?? generateCreateResponse,
    generateContinueResponse: deps?.engine?.generateContinueResponse ?? generateContinueResponse,
  };

  const storage = {
    uploadIllustration:
      deps?.storage?.uploadIllustration ??
      (async (opts) => {
        const bucketName = env.storageBucket;
        const bucket = getStorageBucket(env.projectId, bucketName);
        const objectPath = `stories/${opts.storyId}/chapters/${opts.chapterIndex}/illustration`;

        const ext = opts.contentType.toLowerCase().includes('jpeg') ? 'jpg' : 'png';
        const filePath = `${objectPath}.${ext}`;
        const file = bucket.file(filePath);

        await file.save(opts.bytes, {
          resumable: false,
          contentType: opts.contentType,
          metadata: {
            cacheControl: 'public, max-age=86400',
            metadata: {
              storyId: opts.storyId,
              chapterIndex: String(opts.chapterIndex),
              lang: opts.lang,
            },
          },
        });

        const [url] = await file.getSignedUrl({
          action: 'read',
          expires: Date.now() + opts.signedUrlDays * 24 * 60 * 60 * 1000,
        });

        return {
          url,
          bucket: bucketName,
          storagePath: filePath,
        };
      }),
  };
  const policyLoader = createPolicyLoader({
    firestore: (fs ?? ({} as any)) as any,
    ttlMs: 60_000,
    mode: env.policyMode,
    staticJson: env.policyStaticJson,
  });

  // Lazily initialize firebase-admin only if a request requires token verification.
  const getAdminAppLazy = () => getAdminApp(env.projectId, { storageBucket: env.storageBucket });

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

  function toStoreUnavailable(e: unknown): AppError {
    const msg = String((e as any)?.message ?? e ?? '').trim();
    return new AppError({
      status: 503,
      code: 'STORE_UNAVAILABLE',
      safeMessage: 'Service temporarily disabled',
      message: msg || 'Store unavailable',
    });
  }

  async function withStore<T>(fn: () => Promise<T>): Promise<T> {
    try {
      return await fn();
    } catch (e) {
      if (isAppError(e)) throw e;
      throw toStoreUnavailable(e);
    }
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

  function setDiagHeaders(res: Response, action: 'generate' | 'continue' | 'illustrate') {
    res.setHeader('x-kidstel-rev', serverRevision);
    res.setHeader('x-kidstel-service', serverServiceName);
    res.setHeader('x-kidstel-action', action);
  }

  const app = express();
  app.set('trust proxy', 1);

  const baseDebug = {
    service: processEnv.K_SERVICE ?? null,
    revision: processEnv.K_REVISION ?? null,
    configuration: processEnv.K_CONFIGURATION ?? null,
  };

  // Global revision + debug injector.
  app.use((req, res, next) => {
    const revisionHeader = (baseDebug.revision ?? serverRevision ?? 'dev').toString();
    res.setHeader('x-k-revision', revisionHeader);

    const origJson = res.json.bind(res) as typeof res.json;
    (res as any).json = (body: any) => {
      if (body && typeof body === 'object' && !Array.isArray(body)) {
        const debug =
          (body as any).debug && typeof (body as any).debug === 'object' ? (body as any).debug : {};
        body = {
          ...body,
          debug: {
            ...debug,
            ...baseDebug,
          },
        };
      }
      return origJson(body);
    };

    next();
  });

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
  app.use((err: any, _req: Request, res: Response, next: NextFunction) => {
    // Gracefully handle malformed JSON bodies instead of 500s.
    if (err && (err.type === 'entity.parse.failed' || (err instanceof SyntaxError && 'body' in err))) {
      return respondError(res, 400, 'invalid_json');
    }
    return next(err);
  });

  // Normalize requestId and emit safe request/response logs.
  app.use((req, res, next) => {
    const t0 = Date.now();
    const body = req.body;
    const bodyObj = body && typeof body === 'object' && !Array.isArray(body) ? (body as any) : null;

    const requestId =
      bodyObj && typeof bodyObj.requestId === 'string' && bodyObj.requestId.trim()
        ? bodyObj.requestId.trim()
        : (res.locals as any)?.requestId ?? newRequestId();
    (res.locals as any).requestId = requestId;

    const action = bodyObj ? (bodyObj.action ?? '').toString().trim().toLowerCase() : '';
    const bodyKeys = bodyObj ? Object.keys(bodyObj).slice(0, 32) : [];

    res.on('finish', () => {
      // IMPORTANT: never log auth tokens or full prompts.
      logger.info(
        {
          requestId,
          method: req.method,
          path: req.path,
          status: res.statusCode,
          ms: Date.now() - t0,
          action: action || null,
          contentType: req.headers['content-type'],
          contentLength: req.headers['content-length'],
          bodyKeys,
        },
        'request complete',
      );
    });

    next();
  });

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

    setDiagHeaders(res, 'generate');

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
      if (!takeIpQuota(ip, policy.ip_rate_per_min)) return respondError(res, 429, 'rate_limited');
      if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) return respondError(res, 429, 'rate_limited');

      const contentLen = Number(req.headers['content-length'] ?? '0');
      if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
        return res.status(413).json({ error: 'Request entity too large' });
      }

      const bodyRaw = (req.body ?? {}) as any;
      const storyLangRawFromBody = (bodyRaw?.storyLang ?? bodyRaw?.story_language ?? '').toString().trim();
      const normalizedLang = normalizeLangInput(storyLangRawFromBody);
      if (normalizedLang) bodyRaw.storyLang = normalizedLang;

      const requestId =
        typeof bodyRaw?.requestId === 'string' && bodyRaw.requestId.trim()
          ? bodyRaw.requestId.trim()
          : ((res.locals as any)?.requestId ?? newRequestId());
      (res.locals as any).requestId = requestId;

      // Safe entry log: do not log prompt/idea content.
      const storyLangRaw = (bodyRaw?.storyLang ?? '').toString().trim();
      const langResolved = getLangOrDefault(storyLangRaw);
      const xFirebaseLocale = (req.headers['x-firebase-locale'] ?? '').toString().trim();

      logger.info(
        {
          requestId,
          action: 'generate',
          route,
          storyLangRaw: storyLangRaw || null,
          lang: langResolved,
          xFirebaseLocale: xFirebaseLocale || null,
          contentType: req.headers['content-type'],
          hasStoryId: looksLikeNonEmptyString(bodyRaw?.storyId),
          hasPrompt: looksLikeNonEmptyString(bodyRaw?.prompt),
          hasIdea: looksLikeNonEmptyString(bodyRaw?.idea),
          hasSelection: selectionHasAnyInput(bodyRaw?.selection),
          bodyKeys: safeSortedKeys(bodyRaw),
          ideaLen: safeTextLen(bodyRaw?.idea),
          promptLen: safeTextLen(bodyRaw?.prompt),
        },
        'generate entry',
      );

      // Sanity: some clients may send explicit nulls.
      if (bodyRaw && typeof bodyRaw === 'object' && !Array.isArray(bodyRaw)) {
        if (bodyRaw.storyId === null) delete bodyRaw.storyId;
        if (bodyRaw.prompt === null) delete bodyRaw.prompt;
        if (bodyRaw.idea === null) delete bodyRaw.idea;
      }

      // Strict validations (avoid 500s on missing inputs).
      if (!looksLikeNonEmptyString(bodyRaw?.storyLang)) {
        return respondError(res, 400, 'storyLang_required', { requestId });
      }

      const hasIdea = looksLikeNonEmptyString(bodyRaw?.idea);
      const hasPrompt = looksLikeNonEmptyString(bodyRaw?.prompt);
      const hasStoryId = looksLikeNonEmptyString(bodyRaw?.storyId);
      const hasSelection = selectionHasAnyInput(bodyRaw?.selection);
      if (!hasIdea && !hasPrompt && !hasStoryId && !hasSelection) {
        return respondError(res, 422, 'generate_input_required', {
          requestId,
          hint: 'Provide idea or prompt or storyId or selection',
        });
      }

      const body = CreateRequestSchema.parse(bodyRaw);
      const lang = getLangOrDefault(body.storyLang);
      const allow = Array.isArray(policy.model_allowlist) ? policy.model_allowlist : [];
      const preferred = allow.includes(env.geminiModel) ? env.geminiModel : (allow[0] ?? env.geminiModel);
      const modelCandidates = Array.from(new Set([preferred, ...allow, 'gemini-2.5-flash'])).filter(Boolean);

      const providerSelected = 'vertex';
      const modelSelected = preferred;
      logger.info(
        {
          rid: requestId,
          op: 'generate',
          lang,
          modelSelected,
          providerSelected,
        },
        'llm request',
      );

      if (!env.storeDisabled) {
        if (!fs) throw new AppError({ status: 503, code: 'STORE_UNAVAILABLE', safeMessage: 'Service temporarily disabled' });
        try {
          await withStore(() =>
            store.enforceDailyLimit(fs as any, {
              uid: auth.uid,
              limit: policy.daily_story_limit,
              yyyymmdd: yyyymmdd(new Date()),
            }),
          );
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
            return respondError(res, 429, 'daily_limit_exceeded', { requestId });
          }
          throw toStoreUnavailable(e);
        }
      }

      const combinedInput = JSON.stringify({
        idea: (body.idea ?? body.prompt) ?? '',
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

      let out: any;
      let usedModel: string;
      try {
        const r = await callWithGeminiModelFallback(modelCandidates, (geminiModel) =>
          engine.generateCreateResponse({
            projectId: env.projectId,
            vertexLocation: env.vertexLocation,
            geminiModel,
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
              idea: body.idea ?? body.prompt,
            },
            generation: { maxOutputTokens: policy.max_output_tokens, temperature: policy.temperature },
            requestTimeoutMs: policy.request_timeout_ms,
            mock: env.mockEngine,
          }),
        );
        out = r.out;
        usedModel = r.usedModel;
      } catch (e: any) {
        const attemptedModel = (e as any)?.attemptedModel ?? modelSelected;
        const msgShort = toUpstreamErrorMessageShort(e);
        const status = upstreamStatusFromError(e) ?? (isAppError(e) ? e.status : undefined);
        const svc = upstreamServiceFromMessage(msgShort ?? '') ?? upstreamServiceFromMessage(String((e as any)?.message ?? ''));

        logger.warn(
          {
            rid: requestId,
            op: 'generate',
            lang,
            modelSelected: attemptedModel,
            providerSelected,
            upstreamStatus: status,
            upstreamService: svc,
            upstreamErrorMessageShort: msgShort,
          },
          'llm upstream error',
        );

        if (isUpstreamDailyQuotaExceeded(e)) {
          return res.status(429).json({
            error: 'quota_daily_exceeded',
            retryAfterSec: 86400,
            provider: providerSelected,
            model: attemptedModel,
            requestId,
          });
        }

        // For upstream/service/model failures, never return a generic 500.
        // Emit a controlled 503 with a stable error code and safe metadata.
        if (typeof status === 'number' && Number.isFinite(status)) {
          return respondError(res, 503, 'upstream_unavailable', {
            requestId,
            upstreamStatus: status,
            upstreamService: svc ?? null,
            provider: providerSelected,
            model: attemptedModel,
          });
        }

        // Unknown shape: still treat as transient upstream unavailability.
        return respondError(res, 503, 'upstream_unavailable', {
          requestId,
          upstreamService: svc ?? null,
          provider: providerSelected,
          model: attemptedModel,
        });
      }

      logger.info({ requestId: out.requestId, usedModel }, 'generate used model');

      logger.info(
        {
          rid: requestId,
          op: 'generate',
          lang,
          modelSelected: usedModel,
          providerSelected,
          upstreamStatus: 200,
          upstreamService: 'aiplatform.googleapis.com',
        },
        'llm upstream ok',
      );

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
        const ideaValue = (body.idea ?? body.prompt)?.toString().trim();
        await withStore(() =>
          store.upsertStorySession(fs as any, {
            storyId: out.storyId,
            uid: auth.uid,
            title: out.title,
            lang: body.storyLang ?? lang,
            ageGroup: body.ageGroup,
            storyLength: body.storyLength,
            creativityLevel: body.creativityLevel,
            hero: body.selection?.hero,
            location: body.selection?.location,
            style: body.selection?.style,
            // Firestore does not allow `undefined` values.
            // Omit the field when clients generate from selection-only.
            ...(ideaValue ? { idea: ideaValue } : {}),
            policyVersion: 'v1',
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
          }),
        );

        // Also persist to chapters subcollection for robust continuation.
        await withStore(() =>
          store.writeStoryChapter(fs as any, {
            storyId: out.storyId,
            uid: auth.uid,
            title: out.title,
            lang: (body.storyLang ?? lang).toString(),
            chapter: {
              chapterIndex: out.chapterIndex,
              title: out.title,
              text: out.text,
              progress: out.progress,
              choices: (out.choices ?? []).map((c: any) => ({ id: c.id, label: c.label, payload: c.payload ?? {} })),
              imageUrl: out.image?.url ?? null,
            },
          }),
        );

        await withStore(() =>
          store.writeAudit(fs as any, {
            requestId: out.requestId,
            uid: auth.uid,
            route,
            blocked: false,
            storyId: out.storyId,
          }),
        ).catch(() => undefined);
      }

      return res.status(200).json(out);
    } catch (e: any) {
      if (e instanceof ZodError) {
        logger.warn(
          { err: e, requestId: (res.locals as any)?.requestId ?? null, route, action: 'generate' },
          'create zod validation failed',
        );
        return respondError(res, 400, 'invalid_request', {
          requestId: (res.locals as any)?.requestId ?? null,
          issues: e.issues?.slice(0, 6).map((i) => ({ path: (i.path ?? []).join('.') ?? '', code: i.code })),
        });
      }
      if (isAppError(e)) return res.status(e.status).json(toSafeErrorBody(e));
      logger.error(
        { err: e, requestId: (res.locals as any)?.requestId ?? null, route, action: 'generate' },
        'create failed',
      );
      const requestId = (res.locals as any)?.requestId ?? newRequestId();
      return respondError(res, 503, 'internal_error', {
        requestId,
        errShort: toUpstreamErrorMessageShort(e),
      });
    }
  }

  async function handleContinue(req: Request, res: Response, route: string) {
    if (env.killSwitch) return res.status(503).json({ error: 'Service temporarily disabled' });

    setDiagHeaders(res, 'continue');

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
      if (!takeIpQuota(ip, policy.ip_rate_per_min)) return respondError(res, 429, 'rate_limited');
      if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) return respondError(res, 429, 'rate_limited');

      const contentLen = Number(req.headers['content-length'] ?? '0');
      if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
        return res.status(413).json({ error: 'Request entity too large' });
      }

      const bodyRaw = (req.body ?? {}) as any;
      const normalizedLang = normalizeLangInput(bodyRaw?.storyLang ?? bodyRaw?.story_language);
      if (normalizedLang) bodyRaw.storyLang = normalizedLang;

      const body = ContinueRequestSchema.parse(bodyRaw);

      const requestId =
        typeof (body as any)?.requestId === 'string' && (body as any).requestId.trim()
          ? (body as any).requestId.trim()
          : ((res.locals as any)?.requestId ?? newRequestId());
      (res.locals as any).requestId = requestId;

      // Safe entry log: do not log story text.
      logger.info(
        {
          requestId,
          action: 'continue',
          route,
          storyLangRaw: (body.storyLang ?? '').toString().trim() || null,
          lang: getLangOrDefault(body.storyLang),
          storyId: body.storyId,
          chapterIndex: body.chapterIndex ?? null,
          hasChoice: Boolean(body.choice && Object.keys(body.choice).length),
          bodyKeys: safeSortedKeys(req.body),
        },
        'continue entry',
      );
      const hasChoiceId = (body.choice?.id ?? '').toString().trim().length > 0;
      const hasChoiceLabel = ((body.choice as any)?.label ?? '').toString().trim().length > 0;
      const hasChoiceText = ((body.choice as any)?.text ?? '').toString().trim().length > 0;
      if (!hasChoiceId && !hasChoiceLabel && !hasChoiceText) {
        return res.status(400).json({ error: 'Invalid request' });
      }
      const lang = getLangOrDefault(body.storyLang);
      const allow = Array.isArray(policy.model_allowlist) ? policy.model_allowlist : [];
      const preferred = allow.includes(env.geminiModel) ? env.geminiModel : (allow[0] ?? env.geminiModel);
      const modelCandidates = Array.from(new Set([preferred, ...allow, 'gemini-2.5-flash'])).filter(Boolean);

      const providerSelected = 'vertex';
      const modelSelected = preferred;
      logger.info(
        {
          rid: requestId,
          op: 'continue',
          lang,
          modelSelected,
          providerSelected,
        },
        'llm request',
      );

      if (env.storeDisabled) {
        // Continue requires stored story context.
        return res.status(503).json({ error: 'Service temporarily disabled' });
      }
      if (!fs) throw new AppError({ status: 503, code: 'STORE_UNAVAILABLE', safeMessage: 'Service temporarily disabled' });

      try {
        await withStore(() =>
          store.enforceDailyLimit(fs as any, {
            uid: auth.uid,
            limit: policy.daily_story_limit,
            yyyymmdd: yyyymmdd(new Date()),
          }),
        );
      } catch (e: any) {
        if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
          const requestId = body.requestId?.trim() || ((res.locals as any)?.requestId ?? `req_${randomUUID()}`);
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
          return respondError(res, 429, 'daily_limit_exceeded', { requestId, storyId: body.storyId });
        }
        throw toStoreUnavailable(e);
      }

      const meta = await withStore(() => store.getStoryMeta(fs as any, body.storyId));
      if (!meta) return respondError(res, 404, 'story_not_found');
      if (meta.uid !== auth.uid) return respondError(res, 403, 'forbidden');

      // Prefer chapter subcollection; fall back to story.chapters array.
      const recentChapters = await withStore(() => store.listStoryChapters(fs as any, body.storyId, { limit: 4 }));
      const last = recentChapters.length ? recentChapters[recentChapters.length - 1] : null;
      const prevIndexRaw =
        typeof last?.chapterIndex === 'number'
          ? last.chapterIndex
          : typeof meta.latestChapterIndex === 'number'
            ? meta.latestChapterIndex
            : body.chapterIndex;
      const prevIndex = Number.isFinite(prevIndexRaw as any) ? Number(prevIndexRaw) : 0;
      const expectedNextIndex = prevIndex + 1;

      // Resolve choice label if client didn't send it.
      const choiceId = body.choice?.id?.toString().trim() ?? '';
      const choiceLabelFromClient = body.choice?.label?.toString().trim() || body.choice?.text?.toString().trim() || '';
      const choiceLabelFromStory = (() => {
        if (!last || !choiceId) return '';
        const choices = Array.isArray((last as any).choices) ? (last as any).choices : [];
        const found = choices.find((c: any) => (c?.id ?? '').toString() === choiceId);
        return (found?.label ?? '').toString().trim();
      })();
      const choiceLabel = choiceLabelFromClient || choiceLabelFromStory;

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

      let out: any;
      let usedModel: string;
      try {
        const r = await callWithGeminiModelFallback(modelCandidates, (geminiModel) =>
          engine.generateContinueResponse({
            projectId: env.projectId,
            vertexLocation: env.vertexLocation,
            geminiModel,
            uid: auth.uid,
            previousText: prevText,
            storyTitle: meta.title,
            previousChapters: recentChapters.map((c: any) => ({
              chapterIndex: c.chapterIndex,
              title: c.title,
              text: c.text,
            })),
            userChoiceLabel: choiceLabel,
            request: {
              requestId: body.requestId,
              storyId: body.storyId,
              chapterIndex: prevIndex,
              choice: body.choice ?? {},
              // Prefer stored meta for continuity; fall back to request.
              ageGroup: (meta.ageGroup ?? undefined) as any ?? body.ageGroup,
              storyLang: (meta.lang ?? undefined) as any ?? body.storyLang,
              storyLength: (meta.storyLength ?? undefined) as any ?? body.storyLength,
              hero: (meta.hero ?? undefined) as any ?? body.selection?.hero,
              location: (meta.location ?? undefined) as any ?? body.selection?.location,
              storyType: (meta.style ?? undefined) as any ?? body.selection?.style,
            },
            generation: { maxOutputTokens: policy.max_output_tokens, temperature: policy.temperature },
            requestTimeoutMs: policy.request_timeout_ms,
            mock: env.mockEngine,
          }),
        );
        out = r.out;
        usedModel = r.usedModel;
      } catch (e: any) {
        const attemptedModel = (e as any)?.attemptedModel ?? modelSelected;
        const msgShort = toUpstreamErrorMessageShort(e);
        const status = upstreamStatusFromError(e) ?? (isAppError(e) ? e.status : undefined);
        const svc = upstreamServiceFromMessage(msgShort ?? '') ?? upstreamServiceFromMessage(String((e as any)?.message ?? ''));

        logger.warn(
          {
            rid: requestId,
            op: 'continue',
            lang,
            modelSelected: attemptedModel,
            providerSelected,
            upstreamStatus: status,
            upstreamService: svc,
            upstreamErrorMessageShort: msgShort,
          },
          'llm upstream error',
        );

        if (isUpstreamDailyQuotaExceeded(e)) {
          return res.status(429).json({
            error: 'quota_daily_exceeded',
            retryAfterSec: 86400,
            provider: providerSelected,
            model: attemptedModel,
            requestId,
          });
        }

        if (typeof status === 'number' && Number.isFinite(status)) {
          return respondError(res, 503, 'upstream_unavailable', {
            requestId,
            upstreamStatus: status,
            upstreamService: svc ?? null,
            provider: providerSelected,
            model: attemptedModel,
          });
        }

        return respondError(res, 503, 'upstream_unavailable', {
          requestId,
          upstreamService: svc ?? null,
          provider: providerSelected,
          model: attemptedModel,
        });
      }

      logger.info({ requestId: out.requestId, usedModel }, 'continue used model');

      logger.info(
        {
          rid: requestId,
          op: 'continue',
          lang,
          modelSelected: usedModel,
          providerSelected,
          upstreamStatus: 200,
          upstreamService: 'aiplatform.googleapis.com',
        },
        'llm upstream ok',
      );

      // Guardrail: never allow continue to "restart" or mutate identifiers.
      // The engine already enforces this, but the handler must guarantee it.
      const outFixed = {
        ...out,
        storyId: body.storyId,
        chapterIndex: expectedNextIndex,
      };

      const modOut = moderateText(`${outFixed.title}\n${outFixed.text}`, policy.max_output_chars);
      if (!modOut.allowed) {
        await store.writeAudit(fs as any, {
          requestId: outFixed.requestId,
          uid: auth.uid,
          route,
          blocked: true,
          blockReason: `moderation_output:${modOut.reason}`,
          storyId: outFixed.storyId,
        }).catch(() => undefined);

        res.setHeader('X-KidsTel-Blocked', '1');
        res.setHeader('X-KidsTel-Block-Reason', 'moderation_output');
        return res.status(200).json(
          safeStubResponse({ requestId: outFixed.requestId, storyId: outFixed.storyId, lang, chapterIndex: outFixed.chapterIndex }),
        );
      }

      const nextChapters = recentChapters.concat([
        {
          chapterIndex: outFixed.chapterIndex,
          title: outFixed.title,
          text: outFixed.text,
          progress: outFixed.progress,
          imageUrl: outFixed.image?.url ?? null,
          choices: (outFixed.choices ?? []).map((c: any) => ({ id: c.id, label: c.label, payload: c.payload ?? {} })),
        },
      ]);

      // Persist new chapter into subcollection.
      await withStore(() =>
        store.writeStoryChapter(fs as any, {
          storyId: outFixed.storyId,
          uid: auth.uid,
          title: meta.title ?? outFixed.title,
          lang: (meta.lang ?? body.storyLang ?? lang).toString(),
          chapter: {
            chapterIndex: outFixed.chapterIndex,
            title: outFixed.title,
            text: outFixed.text,
            progress: outFixed.progress,
            choices: (outFixed.choices ?? []).map((c: any) => ({ id: c.id, label: c.label, payload: c.payload ?? {} })),
            imageUrl: outFixed.image?.url ?? null,
          },
        }),
      );

      await withStore(() =>
        store.upsertStorySession(fs as any, {
          storyId: outFixed.storyId,
          uid: auth.uid,
          title: meta.title ?? outFixed.title,
          lang: meta.lang ?? body.storyLang ?? lang,
          ageGroup: meta.ageGroup ?? body.ageGroup,
          storyLength: meta.storyLength ?? body.storyLength,
          creativityLevel: meta.creativityLevel ?? body.creativityLevel,
          hero: meta.hero ?? body.selection?.hero,
          location: meta.location ?? body.selection?.location,
          style: meta.style ?? body.selection?.style,
          idea: meta.idea ?? body.idea,
          policyVersion: meta.policyVersion ?? 'v1',
          chapters: nextChapters,
        }),
      );

      await store.writeAudit(fs as any, {
        requestId: outFixed.requestId,
        uid: auth.uid,
        route,
        blocked: false,
        storyId: outFixed.storyId,
      }).catch(() => undefined);

      return res.status(200).json(outFixed);
    } catch (e: any) {
      if (e instanceof ZodError) return respondError(res, 400, 'invalid_request');
      if (isAppError(e)) return res.status(e.status).json(toSafeErrorBody(e));
      logger.error(
        { err: e, requestId: (res.locals as any)?.requestId ?? null, route, action: 'continue' },
        'continue failed',
      );
      const requestId = (res.locals as any)?.requestId ?? newRequestId();
      return respondError(res, 503, 'internal_error', {
        requestId,
        errShort: toUpstreamErrorMessageShort(e),
      });
    }
  }

  async function handleIllustrate(req: Request, res: Response, route: string) {
    setDiagHeaders(res, 'illustrate');

    const bodyRaw = (req.body ?? {}) as any;
    const requestId =
      typeof bodyRaw?.requestId === 'string' && bodyRaw.requestId.trim()
        ? bodyRaw.requestId.trim()
        : `req_${randomUUID()}`;

    (res.locals as any).requestId = requestId;

    // Safe entry log: do not log prompt content.
    logger.info(
      {
        requestId,
        action: 'illustrate',
        route,
        storyLangRaw: (bodyRaw?.storyLang ?? '').toString().trim() || null,
        lang: getLangOrDefault(bodyRaw?.storyLang),
        storyId: (bodyRaw?.storyId ?? '').toString().trim() || null,
        chapterIndex: typeof bodyRaw?.chapterIndex === 'number' ? bodyRaw.chapterIndex : null,
        promptLen: safeTextLen(bodyRaw?.prompt),
        bodyKeys: safeSortedKeys(bodyRaw),
      },
      'illustrate entry',
    );

    if (env.killSwitch) return res.status(503).json({ ok: false, error: 'Service temporarily disabled', requestId });

    const storyIdInput = bodyRaw?.storyId;
    if (typeof storyIdInput !== 'string' || storyIdInput.trim().length === 0) {
      return respondError(res, 400, 'storyId_required', { requestId });
    }

    const promptInput = bodyRaw?.prompt;
    if (typeof promptInput !== 'string' || promptInput.trim().length === 0) {
      return res.status(400).json({ ok: false, error: 'prompt_required', requestId });
    }

    const chapterIndexInput = bodyRaw?.chapterIndex;
    if (typeof chapterIndexInput !== 'number' || Number.isNaN(chapterIndexInput)) {
      return res.status(400).json({ ok: false, error: 'chapterIndex_required', requestId });
    }

    // Preflight: use derived env values (they include sensible defaults in `readEnv`).
    // We only fail if a value is explicitly empty/malformed.
    const missingEnv: string[] = [];
    if (!env.vertexImageModel?.toString().trim()) missingEnv.push('VERTEX_IMAGE_MODEL');
    if (!env.vertexLocation?.toString().trim()) missingEnv.push('VERTEX_LOCATION');
    if (!env.storageBucket?.toString().trim()) missingEnv.push('STORAGE_BUCKET');
    if (missingEnv.length > 0) {
      return res.status(503).json({ ok: false, error: 'image_pipeline_misconfigured', missing: missingEnv, requestId });
    }

    const tStart = Date.now();

    try {
      const auth = await requireAuth(req, res);
      if (!auth) return;

      const policy = await getPolicyOrFailClosed();

      const ip = (req.ip || req.socket?.remoteAddress || 'unknown').toString();
      if (!takeIpQuota(ip, policy.ip_rate_per_min)) return respondError(res, 429, 'rate_limited', { requestId });
      if (!takeUidQuota(auth.uid, policy.uid_rate_per_min)) return respondError(res, 429, 'rate_limited', { requestId });

      const contentLen = Number(req.headers['content-length'] ?? '0');
      if (Number.isFinite(contentLen) && contentLen > policy.max_body_kb * 1024) {
        return res.status(413).json({ error: 'Request entity too large' });
      }

      const body = IllustrateRequestSchema.parse({
        ...req.body,
        prompt: promptInput,
        chapterIndex: chapterIndexInput,
      });

      if (env.requireIllustrateUserInitiated && body.meta?.userInitiated !== true) {
        return respondError(res, 409, 'illustrate_requires_user_action', { requestId, storyId: body.storyId });
      }

      logger.info(
        {
          requestId,
          route,
          uid: auth.uid,
          storyId: body.storyId,
          chapterIndex: body.chapterIndex,
          promptLen: (body.prompt ?? '').toString().trim().length,
        },
        'illustrate start',
      );

      if (!policy.enable_illustrations) {
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

        return res.status(503).json({ ok: false, error: 'illustrations_disabled', requestId });
      }

      if (env.storeDisabled) {
        return res.status(503).json({ ok: false, error: 'image_pipeline_misconfigured', requestId });
      }
      if (!fs) throw new AppError({ status: 503, code: 'STORE_UNAVAILABLE', safeMessage: 'Service temporarily disabled' });

      try {
        await withStore(() =>
          store.enforceDailyLimit(fs as any, {
            uid: auth.uid,
            limit: policy.daily_story_limit,
            yyyymmdd: yyyymmdd(new Date()),
          }),
        );
      } catch (e: any) {
        if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
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
          return respondError(res, 429, 'daily_limit_exceeded', { requestId, storyId: body.storyId });
        }
        throw toStoreUnavailable(e);
      }

      const meta = await withStore(() => store.getStoryMeta(fs as any, body.storyId));
      if (!meta) return respondError(res, 404, 'story_not_found', { requestId });
      if (meta.uid !== auth.uid) return respondError(res, 403, 'forbidden', { requestId });

      const lang = getLangOrDefault(body.storyLang ?? meta.lang);

      const providerSelected = 'vertex';
      const modelSelected = env.vertexImageModel;
      logger.info(
        {
          rid: requestId,
          op: 'illustrate',
          lang,
          modelSelected,
          providerSelected,
        },
        'llm request',
      );
      const idx = body.chapterIndex;

      const chapter = await withStore(() => store.getStoryChapter(fs as any, body.storyId, idx));
      if (!chapter) return respondError(res, 404, 'chapter_not_found', { requestId });

      const rawPrompt = body.prompt.toString().trim();

      const preferredAgeGroup = ((body as any).ageGroup ?? meta.ageGroup ?? undefined) as any;
      const requestedSizeRaw = ((body as any).image?.size ?? undefined) as any;
      const requestedSize: ImageSize | undefined =
        requestedSizeRaw === '1280x720'
          ? '1280x720'
          : requestedSizeRaw === '512x512'
            ? '512x512'
            : requestedSizeRaw === '768x768'
              ? '768x768'
              : undefined;
      const size = requestedSize ?? ('768x768' as ImageSize);
      const style = (((body as any).image?.style ?? IMAGE_PROMPT_DEFAULTS.style) as string) ?? IMAGE_PROMPT_DEFAULTS.style;
      const universal = buildUniversalImageSystemPrompt({
        lang,
        ageGroup: preferredAgeGroup,
        size,
        style,
      });
      const aspectRaw = ((body as any).image?.aspectRatio ?? undefined) as any;
      const aspectRatio: ImageAspectRatio =
        aspectRaw === '16:9' || aspectRaw === '1:1' ? aspectRaw : universal.aspectRatio;

      // IMPORTANT: never log the prompt.
      const safePrompt = `${universal.systemPrompt}\n\nUser prompt:\n${rawPrompt}`.trim();

      const mod = moderateText(safePrompt, policy.max_input_chars);
      if (!mod.allowed) {
        await store.writeAudit(fs as any, {
          requestId,
          uid: auth.uid,
          route,
          blocked: true,
          blockReason: `moderation_input:${mod.reason}`,
          storyId: body.storyId,
        }).catch(() => undefined);

        // Contract: avoid 200 responses with image.url=null. Use a placeholder base64 instead.
        return res.status(200).json(
          AgentResponseSchema.parse({
            requestId,
            storyId: body.storyId,
            chapterIndex: idx,
            progress: chapter.progress ?? 0,
            title: chapter.title ?? meta.title ?? 'Story',
            text: chapter.text ?? '',
            image: {
              enabled: false,
              disabled: true,
              reason: 'moderation_input',
              base64: TRANSPARENT_1X1_PNG_DATA_URL,
              mimeType: 'image/png',
            },
            choices: [],
          }),
        );
      }

      logger.info(
        {
          requestId,
          uid: auth.uid,
          storyId: body.storyId,
          chapterIndex: idx,
          vertexLocation: env.vertexLocation,
          vertexImageModel: env.vertexImageModel,
          size: universal.size,
          aspectRatio,
          style: universal.style,
        },
        'illustrate vertex call',
      );

      let img: any;
      try {
        img = await image.generateImageBytes({
          projectId: env.projectId,
          location: env.vertexLocation,
          model: env.vertexImageModel,
          prompt: safePrompt,
          aspectRatio,
          sampleCount: 1,
        } as any);
      } catch (e: any) {
        // IMPORTANT: Do not fail the entire request with a 5xx when images are unavailable.
        // The story text is already stored; the app should remain stable.
        if (isAppError(e) && String(e.code ?? '').startsWith('VERTEX_IMAGE_')) {
          const msgShort = toUpstreamErrorMessageShort(e);
          const statusFromMsg = (() => {
            const m = String((e as any)?.message ?? '').match(/http_(\d{3})/i);
            return m ? Number(m[1]) : undefined;
          })();

          logger.warn({ requestId, uid: auth.uid, storyId: body.storyId, chapterIndex: idx, code: e.code }, 'illustrate vertex empty/unavailable; returning placeholder');

          logger.warn(
            {
              rid: requestId,
              op: 'illustrate',
              lang,
              modelSelected,
              providerSelected,
              upstreamStatus: statusFromMsg ?? e.status,
              upstreamService: 'aiplatform.googleapis.com',
              upstreamErrorMessageShort: msgShort,
            },
            'llm upstream error',
          );

          await store.writeAudit(fs as any, {
            requestId,
            uid: auth.uid,
            route,
            blocked: false,
            storyId: body.storyId,
          }).catch(() => undefined);

          return res.status(200).json(
            AgentResponseSchema.parse({
              requestId,
              storyId: body.storyId,
              chapterIndex: idx,
              progress: chapter.progress ?? 0,
              title: chapter.title ?? meta.title ?? 'Story',
              text: chapter.text ?? '',
              image: {
                enabled: false,
                disabled: true,
                reason: String(e.code ?? 'image_unavailable'),
                base64: TRANSPARENT_1X1_PNG_DATA_URL,
                mimeType: 'image/png',
              },
              choices: [],
            }),
          );
        }
        throw e;
      }

      logger.info(
        {
          rid: requestId,
          op: 'illustrate',
          lang,
          modelSelected,
          providerSelected,
          upstreamStatus: 200,
          upstreamService: 'aiplatform.googleapis.com',
        },
        'llm upstream ok',
      );

      if (!img?.bytes || (img.bytes as Buffer).length === 0) {
        // Treat empty bytes like a soft failure too.
        logger.warn({ requestId, uid: auth.uid, storyId: body.storyId, chapterIndex: idx }, 'illustrate returned empty bytes; returning placeholder');
        await store.writeAudit(fs as any, {
          requestId,
          uid: auth.uid,
          route,
          blocked: false,
          storyId: body.storyId,
        }).catch(() => undefined);

        return res.status(200).json(
          AgentResponseSchema.parse({
            requestId,
            storyId: body.storyId,
            chapterIndex: idx,
            progress: chapter.progress ?? 0,
            title: chapter.title ?? meta.title ?? 'Story',
            text: chapter.text ?? '',
            image: {
              enabled: false,
              disabled: true,
              reason: 'image_empty',
              base64: TRANSPARENT_1X1_PNG_DATA_URL,
              mimeType: 'image/png',
            },
            choices: [],
          }),
        );
      }

      logger.info(
        {
          requestId,
          uid: auth.uid,
          storyId: body.storyId,
          chapterIndex: idx,
          bytesLen: (img.bytes as Buffer).length,
          mimeType: img.mimeType,
        },
        'illustrate vertex ok',
      );

      let uploadedUrl: string | undefined;
      let uploadedPath: string | undefined;

      try {
        logger.info(
          { requestId, uid: auth.uid, storyId: body.storyId, chapterIndex: idx, bucket: env.storageBucket },
          'illustrate upload start',
        );
        const uploaded = await storage.uploadIllustration({
          storyId: body.storyId,
          chapterIndex: idx,
          bytes: img.bytes,
          contentType: img.mimeType,
          lang,
          signedUrlDays: env.imageSignedUrlDays,
        });

        uploadedUrl = (uploaded?.url ?? '').toString().trim();
        uploadedPath = uploaded?.storagePath;
        if (!uploadedUrl || !(uploadedUrl.startsWith('https://') || uploadedUrl.startsWith('http://'))) {
          throw new AppError({ status: 502, code: 'IMAGE_UPLOAD_FAILED', safeMessage: 'Illustration unavailable' });
        }

        logger.info(
          {
            requestId,
            uid: auth.uid,
            storyId: body.storyId,
            chapterIndex: idx,
            storagePath: uploadedPath,
            ms: Date.now() - tStart,
          },
          'illustrate upload ok',
        );
      } catch (uploadErr) {
        logger.warn(
          {
            requestId,
            uid: auth.uid,
            storyId: body.storyId,
            chapterIndex: idx,
            err: uploadErr,
          },
          'illustrate upload failed; falling back to base64',
        );
        const base64 = `data:${img.mimeType};base64,${(img.bytes as Buffer).toString('base64')}`;
        await store.writeAudit(fs as any, {
          requestId,
          uid: auth.uid,
          route,
          blocked: false,
          storyId: body.storyId,
        }).catch(() => undefined);

        return res.status(200).json(
          AgentResponseSchema.parse({
            requestId,
            storyId: body.storyId,
            chapterIndex: idx,
            progress: chapter.progress ?? 0,
            title: chapter.title ?? meta.title ?? 'Story',
            text: chapter.text ?? '',
            image: {
              enabled: true,
              base64,
              mimeType: img.mimeType,
              prompt: safePrompt,
            },
            choices: [],
          }),
        );
      }

      await withStore(() =>
        store.updateChapterIllustration(fs as any, {
          storyId: body.storyId,
          chapterIndex: idx,
          imageUrl: uploadedUrl,
          imageStoragePath: `gs://${env.storageBucket}/${uploadedPath}`,
          imagePrompt: safePrompt,
        }),
      );

      await store.writeAudit(fs as any, {
        requestId,
        uid: auth.uid,
        route,
        blocked: false,
        storyId: body.storyId,
      }).catch(() => undefined);

      return res.status(200).json(
        AgentResponseSchema.parse({
          requestId,
          storyId: body.storyId,
          chapterIndex: idx,
          progress: chapter.progress ?? 0,
          title: chapter.title ?? meta.title ?? 'Story',
          text: chapter.text ?? '',
          image: {
            enabled: true,
            url: uploadedUrl,
            prompt: safePrompt,
            storagePath: uploadedPath,
          },
          choices: [],
        }),
      );
    } catch (e: any) {
      logger.error(
        { err: e, requestId: (res.locals as any)?.requestId ?? requestId ?? null, route, action: 'illustrate' },
        'illustrate failed',
      );
      if (e instanceof ZodError) return respondError(res, 400, 'invalid_request', { requestId });
      if (isAppError(e)) return res.status(e.status).json(toSafeErrorBody(e));

      return res.status(503).json({
        ok: false,
        error: 'image_pipeline_failed',
        requestId,
        errShort: toUpstreamErrorMessageShort(e),
      });
    }
  }

  // Backward-compatible endpoint
  app.post('/', async (req, res) => {
    logger.info(
      {
        requestId: (req.body as any)?.requestId,
        contentType: req.headers['content-type'],
        contentLength: req.headers['content-length'],
        bodyType: typeof req.body,
        actionRaw: (req.body as any)?.action,
      },
      'action router entry',
    );

    if (!req.is('application/json')) {
      return respondError(res, 415, 'unsupported_media_type');
    }
    if (req.body == null || typeof req.body !== 'object' || Array.isArray(req.body)) {
      return respondError(res, 400, 'invalid_json');
    }

    const action = (req.body?.action ?? '').toString().trim().toLowerCase();
    if (!action) {
      return respondError(res, 400, 'action_required');
    }
    if (action === 'generate') return handleCreate(req, res, '/');
    if (action === 'continue') return handleContinue(req, res, '/');
    if (action === 'illustrate') return handleIllustrate(req, res, '/');
    return respondError(res, 400, 'action_unsupported', { action });
  });

  // Legacy alias (observed in the wild): some clients/tools call a dedicated route
  // that implied “use chapter language”. We keep it to avoid 404s.
  //
  // Behavior:
  // - If an explicit action is provided, dispatch like the root router.
  // - Otherwise, if the shape matches illustrate, treat it as illustrate.
  // - Else fail with a controlled 400.
  app.post('/WithChapterLanguage', async (req, res) => {
    const bodyObj = req.body && typeof req.body === 'object' && !Array.isArray(req.body) ? (req.body as any) : null;
    if (!req.is('application/json')) {
      return respondError(res, 415, 'unsupported_media_type');
    }
    if (!bodyObj) {
      return respondError(res, 400, 'invalid_json');
    }

    // Normalize legacy language field names.
    if (!looksLikeNonEmptyString(bodyObj.storyLang)) {
      const chapterLang = (bodyObj.chapterLang ?? bodyObj.chapterLanguage ?? bodyObj.lang ?? '').toString().trim();
      if (chapterLang) bodyObj.storyLang = chapterLang;
    }

    const action = (bodyObj.action ?? '').toString().trim().toLowerCase();
    if (action) {
      // Reuse the same handlers.
      if (action === 'generate') return handleCreate(req, res, '/WithChapterLanguage');
      if (action === 'continue') return handleContinue(req, res, '/WithChapterLanguage');
      if (action === 'illustrate') return handleIllustrate(req, res, '/WithChapterLanguage');
      return respondError(res, 400, 'action_unsupported', { action });
    }

    // No action: infer. This route historically was used for illustration.
    const hasStoryId = looksLikeNonEmptyString(bodyObj.storyId);
    const hasPrompt = looksLikeNonEmptyString(bodyObj.prompt);
    const hasChapterIndex = typeof bodyObj.chapterIndex === 'number' && Number.isFinite(bodyObj.chapterIndex);
    if (hasStoryId && hasPrompt && hasChapterIndex) {
      bodyObj.action = 'illustrate';
      return handleIllustrate(req, res, '/WithChapterLanguage');
    }

    return respondError(res, 400, 'invalid_request', {
      hint: 'Use POST / with {action} or /v1/story/{create|continue|illustrate}',
    });
  });

  app.post('/v1/story/create', async (req, res) => handleCreate(req, res, '/v1/story/create'));
  app.post('/v1/story/continue', async (req, res) => handleContinue(req, res, '/v1/story/continue'));
  app.post('/v1/story/illustrate', async (req, res) => handleIllustrate(req, res, '/v1/story/illustrate'));

  return { app, env };
}

const isMain = path.resolve(process.argv[1] ?? '') === fileURLToPath(import.meta.url);

// Cloud Functions Gen2 HTTP trigger entry-point.
// IMPORTANT: must not validate env at module import time (tests/local tooling may import this file).
let cachedApp: ReturnType<typeof createApp> | null = null;
function getOrCreateApp() {
  if (!cachedApp) cachedApp = createApp(process.env);
  return cachedApp;
}

export const LLM_GenerateItem = (req: Request, res: Response) => {
  const { app } = getOrCreateApp();
  return app(req, res);
};

if (isMain) {
  const { app, env } = getOrCreateApp();
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
      return respondError(res, 429, 'rate_limited');
    }

    // Daily limit
    try {
      await enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
    } catch (e: any) {
      if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
        return respondError(res, 429, 'daily_limit_exceeded');
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
      return respondError(res, 429, 'rate_limited');
    }

    try {
      await enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
    } catch (e: any) {
      if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
        return respondError(res, 429, 'daily_limit_exceeded');
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
      return respondError(res, 429, 'rate_limited');
    }

    // Daily limit (illustrations count too, intentionally)
    try {
      await enforceDailyLimit(fs as any, { uid: auth.uid, limit: policy.daily_story_limit, yyyymmdd: yyyymmdd(new Date()) });
    } catch (e: any) {
      if (String(e?.message ?? '').includes('DAILY_LIMIT_EXCEEDED')) {
        return respondError(res, 429, 'daily_limit_exceeded');
      }
      throw e;
    }

    // Validate request shape strictly
    const body = IllustrateRequestSchema.parse(req.body ?? {});

    if (env.requireIllustrateUserInitiated && body.meta?.userInitiated !== true) {
      const requestId = body.requestId?.trim() || ((res.locals as any)?.requestId ?? `req_${randomUUID()}`);
      return respondError(res, 409, 'illustrate_requires_user_action', { requestId, storyId: body.storyId });
    }

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
