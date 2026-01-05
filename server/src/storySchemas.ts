import { z } from 'zod';

export const LangSchema = z.enum(['ru', 'en', 'hy']);
export const AgeGroupSchema = z.enum(['3_5', '6_8', '9_12']);
export const StoryLengthSchema = z.enum(['short', 'medium', 'long']);

const SafeId = z.string().trim().min(1).max(128);
const ShortText = z.string().trim().max(200);
const MediumText = z.string().trim().max(1200);
const LongText = z.string().trim().max(12000);

const RequestMetaSchema = z
  .object({
    // Used to distinguish explicit user actions from background/auto behavior.
    userInitiated: z.boolean().optional(),
  })
  // IMPORTANT: allow forward-compatible keys.
  // Some clients may attach diagnostic/meta fields that older servers shouldn't reject.
  .passthrough();

export const CreateRequestSchema = z
  .object({
    requestId: z.string().trim().max(64).optional(),
    meta: RequestMetaSchema.optional(),
    // Optional: allows clients to send storyId for sanity/compat flows.
    // The create handler may ignore it.
    storyId: SafeId.optional(),
    ageGroup: AgeGroupSchema.optional(),
    storyLang: LangSchema.optional(),
    storyLength: StoryLengthSchema.optional(),
    creativityLevel: z.number().min(0).max(1).optional(),
    image: z.object({ enabled: z.boolean().optional() }).strict().optional(),
    selection: z
      .object({
        hero: ShortText.optional(),
        location: ShortText.optional(),
        // In Flutter we map storyType -> selection.style for backward compatibility.
        style: ShortText.optional(),
      })
      .passthrough()
      .optional(),
    idea: MediumText.optional(),
    // Optional alias for idea (some clients use `prompt` for the initial request).
    prompt: MediumText.optional(),

    // Backward-compat: existing client sends {action: 'generate', ...}
    action: z.literal('generate').optional(),
  })
  // Allow forward-compatible keys without failing validation.
  .passthrough();

export const ContinueRequestSchema = z
  .object({
    requestId: z.string().trim().max(64).optional(),
    meta: RequestMetaSchema.optional(),
    storyId: SafeId,
    chapterIndex: z.number().int().min(0).max(99).optional(),
    choice: z
      .object({
        id: z.string().trim().max(64).optional(),
        // Optional, but helpful for deterministic continuation.
        label: ShortText.optional(),
        // Optional alternate representation.
        choiceIndex: z.number().int().min(0).max(9).optional(),
        text: ShortText.optional(),
        payload: z.record(z.any()).optional(),
      })
      .passthrough()
      .optional(),

    ageGroup: AgeGroupSchema.optional(),
    storyLang: LangSchema.optional(),
    storyLength: StoryLengthSchema.optional(),
    creativityLevel: z.number().min(0).max(1).optional(),
    image: z.object({ enabled: z.boolean().optional() }).strict().optional(),
    selection: z
      .object({
        hero: ShortText.optional(),
        location: ShortText.optional(),
        style: ShortText.optional(),
      })
      .passthrough()
      .optional(),
    idea: MediumText.optional(),

    action: z.literal('continue').optional(),
  })
  .passthrough();

const ImageSizeSchema = z.enum(['1080x1080', '1280x720']);
const ImageAspectRatioSchema = z.enum(['1:1', '16:9']);

export const IllustrateRequestSchema = z
  .object({
    action: z.literal('illustrate').optional(),
    requestId: z.string().trim().max(64).optional(),
    meta: RequestMetaSchema.optional(),
    storyId: SafeId,
    storyLang: LangSchema.optional(),
    ageGroup: AgeGroupSchema.optional(),
    image: z
      .object({
        size: ImageSizeSchema.optional(),
        aspectRatio: ImageAspectRatioSchema.optional(),
        style: z.string().trim().max(64).optional(),
      })
      .passthrough()
      .optional(),
    chapterIndex: z.number().int().min(0).max(99),
    prompt: MediumText.min(1),
  })
  .passthrough();

export const IllustrationResponseSchema = z.object({
  disabled: z.boolean(),
  reason: z.string(),
  image: z.object({
    // May be data URL.
    base64: z.string().min(16).max(200000),
  }).strict(),
}).strict();

export const AgentResponseSchema = z.object({
  requestId: z.string().trim().min(1).max(128),
  storyId: z.string().trim().min(1).max(128),
  chapterIndex: z.number().int().min(0).max(99),
  progress: z.number().min(0).max(1),
  title: z.string().trim().max(140),
  text: LongText,
  image: z
    .object({
      enabled: z.boolean(),
      url: z.string().nullable().optional(),
      // Optional inline image payload.
      base64: z.string().optional(),
      mimeType: z.string().optional(),
      // Optional flags used by some backends.
      disabled: z.boolean().optional(),
      reason: z.string().optional(),
      // Extra metadata (ignored by older clients).
      prompt: z.string().optional(),
      storagePath: z.string().optional(),
    })
    .nullable()
    .optional(),
  choices: z
    .array(
      z.object({
        id: z.string().trim().min(1).max(64),
        label: z.string().trim().min(1).max(80),
        payload: z.record(z.any()).default({}),
      }),
    )
    .max(3)
    .optional(),
}).strict();
