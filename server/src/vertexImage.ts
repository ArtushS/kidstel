import { GoogleAuth } from 'google-auth-library';
import { AppError } from './errors.js';

export type VertexImageGenerateOpts = {
  projectId: string;
  location: string;
  model: string; // e.g. "imagen-3.0-generate-001"
  prompt: string;
  // Optional tuning knobs.
  aspectRatio?: '1:1' | '4:3' | '3:4' | '16:9' | '9:16';
  // 1..4 typical
  sampleCount?: number;
};

export type VertexImageResult = {
  bytes: Buffer;
  mimeType: string; // "image/png" | "image/jpeg"
};

function pickFirstBase64(pred: any): { b64: string; mimeType?: string } | null {
  if (!pred) return null;

  // Common shapes observed across Vertex image models.
  // 1) { bytesBase64Encoded: "...", mimeType: "image/png" }
  if (typeof pred.bytesBase64Encoded === 'string' && pred.bytesBase64Encoded.trim()) {
    return { b64: pred.bytesBase64Encoded.trim(), mimeType: pred.mimeType };
  }

  // 2) { bytes_base64_encoded: "..." }
  if (typeof pred.bytes_base64_encoded === 'string' && pred.bytes_base64_encoded.trim()) {
    return { b64: pred.bytes_base64_encoded.trim(), mimeType: pred.mimeType };
  }

  // 3) { image: { bytesBase64Encoded: "..." } }
  if (pred.image && typeof pred.image.bytesBase64Encoded === 'string' && pred.image.bytesBase64Encoded.trim()) {
    return { b64: pred.image.bytesBase64Encoded.trim(), mimeType: pred.image.mimeType ?? pred.mimeType };
  }

  // 4) { images: [{ bytesBase64Encoded: "..." }] }
  if (Array.isArray(pred.images) && pred.images.length) {
    for (const img of pred.images) {
      if (img && typeof img.bytesBase64Encoded === 'string' && img.bytesBase64Encoded.trim()) {
        return { b64: img.bytesBase64Encoded.trim(), mimeType: img.mimeType ?? pred.mimeType };
      }
    }
  }

  return null;
}

export async function generateImageWithVertex(opts: VertexImageGenerateOpts): Promise<VertexImageResult> {
  const prompt = (opts.prompt ?? '').toString().trim();
  if (!prompt) {
    throw new AppError({ status: 400, code: 'IMAGE_PROMPT_EMPTY', safeMessage: 'Invalid illustration prompt' });
  }

  const auth = new GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });

  const client = await auth.getClient();
  const token = await client.getAccessToken();
  const accessToken = (token?.token ?? '').toString().trim();
  if (!accessToken) {
    throw new AppError({ status: 503, code: 'VERTEX_AUTH_FAILED', safeMessage: 'Illustrations unavailable' });
  }

  const url = `https://${opts.location}-aiplatform.googleapis.com/v1/projects/${opts.projectId}/locations/${opts.location}/publishers/google/models/${opts.model}:predict`;

  // Keep request shape generic and tolerant.
  // IMPORTANT: never log the prompt.
  const body = {
    instances: [{ prompt }],
    parameters: {
      sampleCount: opts.sampleCount ?? 1,
      aspectRatio: opts.aspectRatio ?? '1:1',
      // Safety knobs (model-dependent; ignored if unsupported).
      safetyFilterLevel: 'BLOCK_MEDIUM_AND_ABOVE',
      personGeneration: 'DONT_ALLOW',
    },
  };

  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    // Do not include response body to avoid leaking content.
    throw new AppError({
      status: 502,
      code: 'VERTEX_IMAGE_FAILED',
      safeMessage: 'Illustrations unavailable',
      message: `vertex_image_http_${resp.status}`,
    });
  }

  const json: any = await resp.json();
  const preds = Array.isArray(json?.predictions) ? json.predictions : [];
  if (!preds.length) {
    throw new AppError({ status: 502, code: 'VERTEX_IMAGE_EMPTY', safeMessage: 'Illustrations unavailable' });
  }

  const picked = pickFirstBase64(preds[0]) ?? (preds.length > 1 ? pickFirstBase64(preds[1]) : null);
  if (!picked?.b64) {
    throw new AppError({ status: 502, code: 'VERTEX_IMAGE_BAD_RESPONSE', safeMessage: 'Illustrations unavailable' });
  }

  const bytes = Buffer.from(picked.b64, 'base64');
  if (!bytes.length) {
    throw new AppError({ status: 502, code: 'VERTEX_IMAGE_ZERO_BYTES', safeMessage: 'Illustrations unavailable' });
  }

  const mimeType = (picked.mimeType ?? '').toString().trim() || 'image/png';
  return { bytes, mimeType };
}
