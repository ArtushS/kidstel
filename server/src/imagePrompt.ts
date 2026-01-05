export type ImageSize = '768x768' | '512x512' | '1280x720';
export type ImageAspectRatio = '1:1' | '16:9';

// Centralized prompt defaults for image generation.
// Keep this server-side so Flutter stays thin and behavior is consistent across clients.
export const IMAGE_PROMPT_DEFAULTS = {
  size: '768x768' as ImageSize,
  style:
    "simple 2D children's book illustration, clean lines, flat shading, minimal background, soft pastel colors, no complex textures, no photorealism, single subject, centered composition",
  // We keep it as a human-friendly range for the model.
  ageRange: 'for kids aged 3–7' as const,
};

export const TRANSPARENT_1X1_PNG_DATA_URL =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/xcAAwMCAO9pN1cAAAAASUVORK5CYII=';

export function sizeToAspectRatio(size: ImageSize): ImageAspectRatio {
  return size === '1280x720' ? '16:9' : '1:1';
}

function ageGroupToRange(ageGroup: string | undefined): string {
  const v = (ageGroup ?? '').toString().trim();
  if (v === '3_5') return 'for kids aged 3–5';
  if (v === '6_8') return 'for kids aged 6–8';
  if (v === '9_12') return 'for kids aged 9–12';
  return IMAGE_PROMPT_DEFAULTS.ageRange;
}

export function buildUniversalImageSystemPrompt(opts: {
  lang: string;
  ageGroup?: string;
  size?: ImageSize;
  style?: string;
}): { systemPrompt: string; size: ImageSize; aspectRatio: ImageAspectRatio; style: string; ageRange: string } {
  const size = (opts.size ?? IMAGE_PROMPT_DEFAULTS.size) as ImageSize;
  const aspectRatio = sizeToAspectRatio(size);
  const style = (opts.style ?? IMAGE_PROMPT_DEFAULTS.style).toString().trim() || IMAGE_PROMPT_DEFAULTS.style;
  const ageRange = ageGroupToRange(opts.ageGroup);

  // IMPORTANT: Keep this prompt kid-safe and performance-friendly.
  const systemPrompt = [
    "You are generating a kid-friendly 2D illustration for a children's story.",
    `Target age: ${ageRange}.`,
    `Language/locale: ${opts.lang}.`,
    `Image size: ${size}. Aspect ratio: ${aspectRatio}.`,
    `Style: ${style}.`,
    'No photorealism. No camera/photography terms. No realistic skin texture.',
    'Simple shapes, soft colors, clean outlines, gentle lighting, minimal background.',
    'Warm, friendly mood. Non-scary, calm and reassuring.',
    'Single subject, centered composition, one clear scene. No text overlay.',
    'Safety: no violence, no horror, no weapons, no hateful symbols.',
  ]
    .join('\n')
    .trim();

  return { systemPrompt, size, aspectRatio, style, ageRange };
}
