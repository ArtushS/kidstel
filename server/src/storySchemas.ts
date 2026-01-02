import { z } from 'zod';

export const LangSchema = z.enum(['ru', 'en', 'hy']);
export const AgeGroupSchema = z.enum(['3_5', '6_8', '9_12']);
export const StoryLengthSchema = z.enum(['short', 'medium', 'long']);

const SafeId = z.string().trim().min(1).max(128);
const ShortText = z.string().trim().max(200);
const MediumText = z.string().trim().max(1200);
const LongText = z.string().trim().max(12000);

export const CreateRequestSchema = z.object({
  requestId: z.string().trim().max(64).optional(),
  ageGroup: AgeGroupSchema.optional(),
  storyLang: LangSchema.optional(),
  storyLength: StoryLengthSchema.optional(),
  creativityLevel: z.number().min(0).max(1).optional(),
  image: z.object({ enabled: z.boolean().optional() }).strict().optional(),
  selection: z.object({
    hero: ShortText.optional(),
    location: ShortText.optional(),
    // In Flutter we map storyType -> selection.style for backward compatibility.
    style: ShortText.optional(),
  }).strict().optional(),
  idea: MediumText.optional(),

  // Backward-compat: existing client sends {action: 'generate', ...}
  action: z.literal('generate').optional(),
}).strict();

export const ContinueRequestSchema = z.object({
  requestId: z.string().trim().max(64).optional(),
  storyId: SafeId,
  chapterIndex: z.number().int().min(0).max(99).optional(),
  choice: z.object({
    id: z.string().trim().max(64).optional(),
    payload: z.record(z.any()).optional(),
  }).strict().optional(),

  ageGroup: AgeGroupSchema.optional(),
  storyLang: LangSchema.optional(),
  storyLength: StoryLengthSchema.optional(),
  creativityLevel: z.number().min(0).max(1).optional(),
  image: z.object({ enabled: z.boolean().optional() }).strict().optional(),
  selection: z.object({
    hero: ShortText.optional(),
    location: ShortText.optional(),
    style: ShortText.optional(),
  }).strict().optional(),
  idea: MediumText.optional(),

  action: z.literal('continue').optional(),
}).strict();

export const IllustrateRequestSchema = z.object({
  action: z.literal('illustrate').optional(),
  requestId: z.string().trim().max(64).optional(),
  storyId: SafeId,
  storyLang: LangSchema.optional(),
  chapterIndex: z.number().int().min(0).max(99).optional(),
  prompt: MediumText.optional(),
}).strict();

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
