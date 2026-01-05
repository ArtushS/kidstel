import { z } from 'zod';

const boolFromString = (v: string | undefined, def: boolean) => {
  if (v == null || v.trim() === '') return def;
  const s = v.trim().toLowerCase();
  if (s === '1' || s === 'true' || s === 'yes') return true;
  if (s === '0' || s === 'false' || s === 'no') return false;
  return def;
};

const EnvSchema = z.object({
  // Runtime
  PORT: z.string().optional(),
  NODE_ENV: z.string().optional(),

  // GCP/Firebase
  GOOGLE_CLOUD_PROJECT: z.string().min(1),
  FIREBASE_PROJECT_ID: z.string().optional(),
  FIRESTORE_DATABASE_ID: z.string().optional(), // defaults to "(default)"

  // Auth/AppCheck enforcement
  AUTH_REQUIRED: z.string().optional(),
  APPCHECK_REQUIRED: z.string().optional(),

  // Vertex AI
  VERTEX_LOCATION: z.string().default('us-central1'),
  // NOTE: gemini-1.5-* models have retirement dates and can start returning 404.
  // Use an auto-updated alias that always points to the latest stable Flash model.
  GEMINI_MODEL: z.string().default('gemini-2.5-flash'),

  // Firebase Storage
  STORAGE_BUCKET: z.string().optional(), // defaults to "<projectId>.appspot.com"

  // Vertex AI image generation (Imagen)
  VERTEX_IMAGE_MODEL: z.string().optional(), // defaults to "imagen-3.0-generate-001"
  IMAGE_SIGNED_URL_DAYS: z.string().optional(), // defaults to 30

  // Policy / limits
  KILL_SWITCH: z.string().optional(),
  MAX_INPUT_CHARS: z.string().optional(),
  MAX_OUTPUT_CHARS: z.string().optional(),
  DAILY_STORY_LIMIT: z.string().optional(),
  AUDIT_STORE_TEXT: z.string().optional(),

  // Safety: optionally require the client to mark illustration calls as
  // explicitly user-initiated (prevents background/auto illustrate flows).
  REQUIRE_ILLUSTRATE_USER_INITIATED: z.string().optional(),

  // Admin policy loader
  POLICY_MODE: z.string().optional(), // 'firestore' (default) | 'static'
  POLICY_STATIC_JSON: z.string().optional(),

  // Dev/testing
  MOCK_ENGINE: z.string().optional(),
  STORE_DISABLED: z.string().optional(),
});

export type Env = {
  port: number;
  projectId: string;
  firestoreDatabaseId: string;
  authRequired: boolean;
  appCheckRequired: boolean;
  vertexLocation: string;
  geminiModel: string;
  storageBucket: string;
  vertexImageModel: string;
  imageSignedUrlDays: number;
  killSwitch: boolean;
  maxInputChars: number;
  maxOutputChars: number;
  dailyStoryLimit: number;
  auditStoreText: boolean;
  requireIllustrateUserInitiated: boolean;

  policyMode: 'firestore' | 'static';
  policyStaticJson: string;
  mockEngine: boolean;
  storeDisabled: boolean;
};

export function readEnv(processEnv: NodeJS.ProcessEnv): Env {
  const parsed = EnvSchema.parse(processEnv);

  const projectId = (parsed.FIREBASE_PROJECT_ID ?? parsed.GOOGLE_CLOUD_PROJECT).trim();
  const storageBucket = (parsed.STORAGE_BUCKET ?? `${projectId}.appspot.com`).trim();

  return {
    port: Number(parsed.PORT ?? '8080'),
    projectId,
    firestoreDatabaseId: (parsed.FIRESTORE_DATABASE_ID ?? '(default)').trim(),
    authRequired: boolFromString(parsed.AUTH_REQUIRED, true),
    appCheckRequired: boolFromString(parsed.APPCHECK_REQUIRED, true),
    vertexLocation: parsed.VERTEX_LOCATION,
    geminiModel: parsed.GEMINI_MODEL,
    storageBucket,
    vertexImageModel: (parsed.VERTEX_IMAGE_MODEL ?? 'imagen-3.0-generate-001').trim(),
    imageSignedUrlDays: Number(parsed.IMAGE_SIGNED_URL_DAYS ?? '30'),
    killSwitch: boolFromString(parsed.KILL_SWITCH, false),
    maxInputChars: Number(parsed.MAX_INPUT_CHARS ?? '1200'),
    maxOutputChars: Number(parsed.MAX_OUTPUT_CHARS ?? '12000'),
    dailyStoryLimit: Number(parsed.DAILY_STORY_LIMIT ?? '40'),
    auditStoreText: boolFromString(parsed.AUDIT_STORE_TEXT, false),

    requireIllustrateUserInitiated: boolFromString(parsed.REQUIRE_ILLUSTRATE_USER_INITIATED, false),

    policyMode: ((parsed.POLICY_MODE ?? 'firestore').trim().toLowerCase() === 'static')
      ? 'static'
      : 'firestore',
    policyStaticJson: (parsed.POLICY_STATIC_JSON ?? '').toString(),
    mockEngine: boolFromString(parsed.MOCK_ENGINE, false),
    storeDisabled: boolFromString(parsed.STORE_DISABLED, false),
  };
}
