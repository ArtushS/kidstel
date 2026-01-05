import { randomUUID } from 'crypto';
import { createVertexModel } from './vertex.js';
import { KIDS_POLICY_SYSTEM } from './moderation.js';
import { AgentResponseSchema } from './storySchemas.js';
import { AppError } from './errors.js';
import { ZodError } from 'zod';

function rid(prefix: string) {
  return `${prefix}_${randomUUID()}`;
}

function safeJsonParse(text: string): unknown {
  const t = text.trim();
  // Some models may wrap JSON in markdown fences.
  const stripped = t
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '');
  return JSON.parse(stripped);
}

function toUpstreamAppError(e: unknown): AppError {
  // Normalize the many Vertex client error shapes into a safe AppError.
  // IMPORTANT: never include raw upstream payloads in messages.
  const msg = String((e as any)?.message ?? '');
  const msgShort = msg
    .replace(/[\r\n\t]+/g, ' ')
    .replace(/\s\s+/g, ' ')
    .trim()
    .slice(0, 240);

  // Vertex SDK often includes: "got status: 429" etc.
  const m = msg.match(/got status:\s*(\d{3})/i);
  const statusFromMsg = m ? Number(m[1]) : NaN;

  const status = Number.isFinite(statusFromMsg)
    ? statusFromMsg
    : typeof (e as any)?.status === 'number'
      ? (e as any).status
      : typeof (e as any)?.code === 'number'
        ? (e as any).code
        : undefined;

  if (status === 429) {
    // Some quota issues are *daily* and should not be treated like normal rate limiting.
    // Vertex/GAX error messages vary; keep checks fuzzy but safe.
    const isDailyQuota = /daily limit exceeded/i.test(msg) || /(quota|limit).*(per day|daily)/i.test(msg);
    if (isDailyQuota) {
      return new AppError({
        status: 429,
        code: 'UPSTREAM_DAILY_QUOTA',
        safeMessage: 'Quota exceeded. Please try again later.',
        message: msgShort || 'upstream_daily_quota',
      });
    }

    return new AppError({
      status: 429,
      code: 'VERTEX_TEXT_RATE_LIMIT',
      safeMessage: 'Too many requests. Please retry.',
      message: msgShort || 'upstream_rate_limited',
    });
  }
  if (status === 403) {
    // Misconfiguration (permissions, org policy, etc.).
    return new AppError({
      status: 503,
      code: 'VERTEX_TEXT_FORBIDDEN',
      safeMessage: 'Service temporarily unavailable',
      message: msgShort || 'upstream_forbidden',
    });
  }
  if (status === 404) {
    // Model not found is handled by model fallback higher up, but keep it safe here too.
    return new AppError({
      status: 503,
      code: 'VERTEX_TEXT_MODEL_NOT_FOUND',
      safeMessage: 'Service temporarily unavailable',
      message: msgShort || 'upstream_model_not_found',
    });
  }
  if (status === 400) {
    // Bad request to upstream (often model parameter mismatch / API change).
    return new AppError({
      status: 503,
      code: 'VERTEX_TEXT_BAD_REQUEST',
      safeMessage: 'Service temporarily unavailable',
      message: msgShort || 'upstream_bad_request',
    });
  }
  if (status === 500 || status === 502 || status === 503) {
    return new AppError({
      status: 503,
      code: 'VERTEX_TEXT_UNAVAILABLE',
      safeMessage: 'Service temporarily unavailable',
      message: msgShort || 'upstream_unavailable',
    });
  }

  // Fallback: treat as transient upstream failure.
  return new AppError({
    status: 503,
    code: 'VERTEX_TEXT_FAILED',
    safeMessage: 'Service temporarily unavailable',
    message: msgShort || 'upstream_failed',
  });
}

async function withTimeout<T>(p: Promise<T>, ms: number): Promise<T> {
  let t: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_resolve, reject) => {
    t = setTimeout(() => {
      reject(new AppError({ status: 504, code: 'UPSTREAM_TIMEOUT', safeMessage: 'Request timeout' }));
    }, ms);
  });
  try {
    return await Promise.race([p, timeout]);
  } finally {
    if (t) clearTimeout(t);
  }
}

export async function generateCreateResponse(opts: {
  projectId: string;
  vertexLocation: string;
  geminiModel: string;
  request: {
    requestId?: string;
    ageGroup?: string;
    storyLang?: string;
    storyLength?: string;
    creativityLevel?: number;
    imageEnabled?: boolean;
    hero?: string;
    location?: string;
    storyType?: string;
    idea?: string;
  };
  uid: string;
  generation: { maxOutputTokens: number; temperature: number };
  requestTimeoutMs?: number;
  mock?: boolean;
}): Promise<any> {
  const requestId = opts.request.requestId?.trim() || rid('req');
  const storyId = rid('story');

  if (opts.mock) {
    const mock = AgentResponseSchema.parse({
      requestId,
      storyId,
      chapterIndex: 0,
      progress: 0.25,
      title: 'Mock Story',
      text: 'This is a mock story response used for tests/local development.',
      image: { enabled: false, url: null },
      choices: [
        { id: 'c1', label: 'Continue', payload: { action: 'continue' } },
      ],
    });
    return mock;
  }

  const model = createVertexModel({
    projectId: opts.projectId,
    location: opts.vertexLocation,
    model: opts.geminiModel,
  });

  const prompt = {
    system: KIDS_POLICY_SYSTEM,
    user: {
      task: 'Create a new kid-safe story chapter (chapterIndex=0) with 3 short choices for continuation.',
      constraints: {
        maxChoices: 3,
        language: opts.request.storyLang ?? 'en',
        ageGroup: opts.request.ageGroup ?? '3_5',
        storyLength: opts.request.storyLength ?? 'medium',
      },
      selection: {
        hero: opts.request.hero ?? '',
        location: opts.request.location ?? '',
        storyType: opts.request.storyType ?? '',
      },
      idea: opts.request.idea ?? '',
      outputSchema: {
        requestId: 'string',
        storyId: 'string',
        chapterIndex: 'number',
        progress: 'number (0..1)',
        title: 'string',
        text: 'string',
        image: { enabled: 'boolean', url: 'string|null' },
        choices: [
          { id: 'string', label: 'string', payload: { any: 'json' } },
        ],
      },
      outputRules: [
        'Return ONLY JSON. No markdown.',
        'Keep the story gentle, positive, and appropriate for children.',
        'No scary or violent elements.',
        'Choices must be safe and kid-friendly.',
      ],
      metadata: { uid: opts.uid },
    },
  };

  const resp = await withTimeout(
    model
      .generateContent({
        contents: [{ role: 'user', parts: [{ text: JSON.stringify(prompt) }] }],
        generationConfig: {
          temperature: opts.generation.temperature,
          maxOutputTokens: opts.generation.maxOutputTokens,
          responseMimeType: 'application/json',
        },
        safetySettings: [
          { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
          { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_LOW_AND_ABOVE' },
          { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
          { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        ],
      } as any)
      .catch((e: unknown) => {
        throw toUpstreamAppError(e);
      }),
    opts.requestTimeoutMs ?? 25_000,
  );

  const text = (resp.response?.candidates?.[0]?.content?.parts?.[0] as any)?.text ?? '';
  let validated: any;
  try {
    const parsed = safeJsonParse(text);
    validated = AgentResponseSchema.parse(parsed);
  } catch (e: any) {
    // Model returned invalid JSON or wrong schema.
    if (e instanceof SyntaxError || e instanceof ZodError) {
      throw new AppError({
        status: 502,
        code: 'VERTEX_TEXT_BAD_RESPONSE',
        safeMessage: 'Service temporarily unavailable',
      });
    }
    throw e;
  }

  // Override ids to ensure stable server control.
  return {
    ...validated,
    requestId,
    storyId,
    chapterIndex: 0,
    progress: Math.max(0, Math.min(1, validated.progress ?? 0.2)),
    image: { enabled: Boolean(opts.request.imageEnabled), url: null },
    choices: (validated.choices ?? []).slice(0, 3),
  };
}

export async function generateContinueResponse(opts: {
  projectId: string;
  vertexLocation: string;
  geminiModel: string;
  request: {
    requestId?: string;
    storyId: string;
    chapterIndex?: number;
    choice?: { id?: string; payload?: Record<string, any> };
    storyLang?: string;
    ageGroup?: string;
    storyLength?: string;
    hero?: string;
    location?: string;
    storyType?: string;
  };
  uid: string;
  previousText: string;
  // Optional richer context (preferred over previousText).
  storyTitle?: string;
  previousChapters?: Array<{ chapterIndex: number; title?: string; text: string }>;
  userChoiceLabel?: string;
  generation: { maxOutputTokens: number; temperature: number };
  requestTimeoutMs?: number;
  mock?: boolean;
}): Promise<any> {
  const requestId = opts.request.requestId?.trim() || rid('req');

  if (opts.mock) {
    const nextIndex = (opts.request.chapterIndex ?? 0) + 1;
    const mock = AgentResponseSchema.parse({
      requestId,
      storyId: opts.request.storyId,
      chapterIndex: nextIndex,
      progress: Math.min(1, 0.25 + nextIndex * 0.25),
      title: 'Mock Story',
      text: 'This is a mock continuation response used for tests/local development.',
      image: { enabled: false, url: null },
      choices: [],
    });
    return mock;
  }

  const model = createVertexModel({
    projectId: opts.projectId,
    location: opts.vertexLocation,
    model: opts.geminiModel,
  });

  const nextIndex = (opts.request.chapterIndex ?? 0) + 1;

  const chapters = Array.isArray(opts.previousChapters) ? opts.previousChapters : [];
  const trimmedChapters = chapters
    .filter((c) => c && typeof c.text === 'string')
    .slice(-4)
    .map((c) => ({
      chapterIndex: c.chapterIndex,
      title: (c.title ?? '').toString().trim(),
      text: c.text.toString(),
    }));

  const prompt = {
    system: KIDS_POLICY_SYSTEM,
    user: {
      task: `Continue the SAME story with the next chapter (chapterIndex=${nextIndex}). Do NOT restart the story or introduce a new unrelated idea.`,
      constraints: {
        maxChoices: 3,
        language: opts.request.storyLang ?? 'en',
        ageGroup: opts.request.ageGroup ?? '3_5',
        storyLength: opts.request.storyLength ?? 'medium',
      },
      selection: {
        hero: opts.request.hero ?? '',
        location: opts.request.location ?? '',
        storyType: opts.request.storyType ?? '',
      },
      previous: {
        storyId: opts.request.storyId,
        storyTitle: (opts.storyTitle ?? '').toString().trim(),
        // Prefer multi-chapter context when provided.
        chapters: trimmedChapters.length
          ? trimmedChapters
          : [
              {
                chapterIndex: opts.request.chapterIndex ?? 0,
                title: (opts.storyTitle ?? '').toString().trim(),
                text: opts.previousText,
              },
            ],
      },
      userChoice: {
        ...(opts.request.choice ?? {}),
        label: (opts.userChoiceLabel ?? '').toString().trim(),
      },
      outputSchema: {
        requestId: 'string',
        storyId: 'string',
        chapterIndex: 'number',
        progress: 'number (0..1)',
        title: 'string',
        text: 'string',
        image: { enabled: 'boolean', url: 'string|null' },
        choices: [
          { id: 'string', label: 'string', payload: { any: 'json' } },
        ],
      },
      outputRules: [
        'Return ONLY JSON. No markdown.',
        'Keep it kid-safe and reassuring.',
        'Maintain continuity: same characters, setting, and tone.',
        'Use the user choice to decide what happens next.',
      ],
      metadata: { uid: opts.uid },
    },
  };

  const resp = await withTimeout(
    model
      .generateContent({
        contents: [{ role: 'user', parts: [{ text: JSON.stringify(prompt) }] }],
        generationConfig: {
          temperature: opts.generation.temperature,
          maxOutputTokens: opts.generation.maxOutputTokens,
          responseMimeType: 'application/json',
        },
        safetySettings: [
          { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
          { category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT', threshold: 'BLOCK_LOW_AND_ABOVE' },
          { category: 'HARM_CATEGORY_DANGEROUS_CONTENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
          { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_MEDIUM_AND_ABOVE' },
        ],
      } as any)
      .catch((e: unknown) => {
        throw toUpstreamAppError(e);
      }),
    opts.requestTimeoutMs ?? 25_000,
  );

  const text = (resp.response?.candidates?.[0]?.content?.parts?.[0] as any)?.text ?? '';
  let validated: any;
  try {
    const parsed = safeJsonParse(text);
    validated = AgentResponseSchema.parse(parsed);
  } catch (e: any) {
    if (e instanceof SyntaxError || e instanceof ZodError) {
      throw new AppError({
        status: 502,
        code: 'VERTEX_TEXT_BAD_RESPONSE',
        safeMessage: 'Service temporarily unavailable',
      });
    }
    throw e;
  }

  return {
    ...validated,
    requestId,
    storyId: opts.request.storyId,
    chapterIndex: nextIndex,
    progress: Math.max(0, Math.min(1, validated.progress ?? Math.min(1, nextIndex * 0.25))),
  };
}
