import { randomUUID } from 'crypto';
import { createVertexModel } from './vertex.js';
import { KIDS_POLICY_SYSTEM } from './moderation.js';
import { AgentResponseSchema } from './storySchemas.js';
import { AppError } from './errors.js';

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
    model.generateContent({
    contents: [
      { role: 'user', parts: [{ text: JSON.stringify(prompt) }] },
    ],
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
      { category: 'HARM_CATEGORY_VIOLENCE', threshold: 'BLOCK_LOW_AND_ABOVE' },
    ],
    } as any),
    opts.requestTimeoutMs ?? 25_000,
  );

  const text = (resp.response?.candidates?.[0]?.content?.parts?.[0] as any)?.text ?? '';
  const parsed = safeJsonParse(text);
  const validated = AgentResponseSchema.parse(parsed);

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

  const prompt = {
    system: KIDS_POLICY_SYSTEM,
    user: {
      task: `Continue the existing story with the next chapter (chapterIndex=${nextIndex}).`,
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
        lastChapterText: opts.previousText,
      },
      userChoice: opts.request.choice ?? {},
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
      ],
      metadata: { uid: opts.uid },
    },
  };

  const resp = await withTimeout(
    model.generateContent({
    contents: [
      { role: 'user', parts: [{ text: JSON.stringify(prompt) }] },
    ],
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
      { category: 'HARM_CATEGORY_VIOLENCE', threshold: 'BLOCK_LOW_AND_ABOVE' },
    ],
    } as any),
    opts.requestTimeoutMs ?? 25_000,
  );

  const text = (resp.response?.candidates?.[0]?.content?.parts?.[0] as any)?.text ?? '';
  const parsed = safeJsonParse(text);
  const validated = AgentResponseSchema.parse(parsed);

  return {
    ...validated,
    requestId,
    storyId: opts.request.storyId,
    chapterIndex: nextIndex,
    progress: Math.max(0, Math.min(1, validated.progress ?? Math.min(1, nextIndex * 0.25))),
  };
}
