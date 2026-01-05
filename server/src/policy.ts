import { z } from 'zod';
import type { Firestore } from 'firebase-admin/firestore';
import { logger } from './logging.js';

// One document: admin_policy/runtime
export const RuntimePolicySchema = z
  .object({
    enable_story_generation: z.boolean().default(false),
    enable_illustrations: z.boolean().default(false),

    // Model controls
  // Use an auto-updated alias as default to avoid hard failures when older models retire.
  model_allowlist: z.array(z.string().min(1)).default(['gemini-2.5-flash']),
    max_output_tokens: z.number().int().min(64).max(4096).default(1200),
    temperature: z.number().min(0).max(1.2).default(0.7),

    // Limits
    max_input_chars: z.number().int().min(200).max(5000).default(1200),
    max_output_chars: z.number().int().min(500).max(30000).default(12000),
    daily_story_limit: z.number().int().min(1).max(500).default(40),

    // Rate limiting (per instance; Cloud Run may scale)
    ip_rate_per_min: z.number().int().min(1).max(600).default(120),
    uid_rate_per_min: z.number().int().min(1).max(300).default(60),

    // Body size
    max_body_kb: z.number().int().min(8).max(256).default(64),

    // Request timeout
    request_timeout_ms: z.number().int().min(1000).max(60000).default(25000),
  })
  .strict();

export type RuntimePolicy = z.infer<typeof RuntimePolicySchema>;

type Cached<T> = { value: T; expiresAt: number };

export function createPolicyLoader(opts: {
  firestore: Firestore;
  ttlMs?: number;
  mode: 'firestore' | 'static';
  staticJson: string;
}): {
  getPolicy: () => Promise<RuntimePolicy | null>; // null => fail-closed
} {
  const ttlMs = opts.ttlMs ?? 60_000;
  let cache: Cached<RuntimePolicy> | null = null;

  function normalizeModelAllowlist(list: string[] | undefined | null): string[] {
    const raw = Array.isArray(list) ? list : [];
    const mapped = raw
      .map((s) => (s ?? '').toString().trim())
      .filter((s) => s.length > 0)
      .map((s) => {
        // Auto-migrate known retired IDs.
        if (s === 'gemini-1.5-flash') return 'gemini-2.5-flash';
        return s;
      });

    const uniq = Array.from(new Set(mapped));
    return uniq.length ? uniq : ['gemini-2.5-flash'];
  }

  async function loadFromFirestore(): Promise<RuntimePolicy> {
    const ref = opts.firestore.collection('admin_policy').doc('runtime');
    const snap = await ref.get();

    if (!snap.exists) {
      // Ensure a sane default exists so the service never silently returns disabled.
      const defaults = {
        enable_story_generation: true,
        enable_illustrations: true,
      };

      try {
        await ref.set(defaults, { merge: true });
      } catch (e) {
        // Log and continue to parse the defaults locally.
        logger.error({ err: e }, 'failed to seed runtime policy; continuing with defaults');
      }

      const parsed = RuntimePolicySchema.parse(defaults);
      return {
        ...parsed,
        model_allowlist: normalizeModelAllowlist(parsed.model_allowlist),
      };
    }

    const raw = snap.data();
    // Even if document missing keys: rely on schema defaults.
    const parsed = RuntimePolicySchema.parse(raw ?? {});
    return {
      ...parsed,
      model_allowlist: normalizeModelAllowlist(parsed.model_allowlist),
    };
  }

  async function loadFromStatic(): Promise<RuntimePolicy> {
    const s = (opts.staticJson ?? '').trim();
    if (!s) {
      // Fail-closed
      return RuntimePolicySchema.parse({ enable_story_generation: false });
    }
    const parsed = JSON.parse(s);
    const policy = RuntimePolicySchema.parse(parsed);
    return {
      ...policy,
      model_allowlist: normalizeModelAllowlist(policy.model_allowlist),
    };
  }

  return {
    async getPolicy() {
      const now = Date.now();
      if (cache && cache.expiresAt > now) return cache.value;

      try {
        const policy = opts.mode === 'static' ? await loadFromStatic() : await loadFromFirestore();
        cache = { value: policy, expiresAt: now + ttlMs };
        return policy;
      } catch (e) {
        logger.error({ err: e }, 'policy load failed; fail-closed');
        cache = null;
        return null;
      }
    },
  };
}
