import admin from 'firebase-admin';
import type { Request } from 'express';
import { randomUUID } from 'crypto';
import { AppError } from './errors.js';

export type VerifiedRequestAuth = {
  uid: string;
  idToken: admin.auth.DecodedIdToken;
  appCheckToken?: admin.appCheck.VerifyAppCheckTokenResponse;
};

function getBearerToken(req: Request): string | null {
  const h = req.header('authorization') ?? req.header('Authorization');
  if (!h) return null;
  const m = h.match(/^Bearer\s+(.+)$/i);
  return m ? m[1].trim() : null;
}

function getAppCheckToken(req: Request): string | null {
  // Standard header used by Firebase SDKs.
  const h = req.header('X-Firebase-AppCheck') ?? req.header('x-firebase-appcheck');
  if (!h) return null;
  return h.trim();
}

function getDevUid(req: Request): string | null {
  // DEV/TEST ONLY: allow stable anonymous uid across requests when AUTH_REQUIRED=false.
  // This is never used in production auth flows.
  const h = req.header('X-KidsTel-Dev-Uid') ?? req.header('x-kidstel-dev-uid');
  if (!h) return null;
  const v = h.trim();
  if (!v) return null;
  // Keep it conservative.
  if (!/^[a-zA-Z0-9_\-]{3,64}$/.test(v)) return null;
  return v;
}

export async function verifyRequestTokens(opts: {
  req: Request;
  getAdminApp: () => admin.app.App;
  authRequired: boolean;
  appCheckRequired: boolean;
}): Promise<VerifiedRequestAuth | null> {
  const { req, getAdminApp, authRequired, appCheckRequired } = opts;

  const bearer = getBearerToken(req);

  let decoded: admin.auth.DecodedIdToken;
  if (!bearer) {
    if (authRequired) {
      throw new AppError({
        status: 401,
        code: 'AUTH_MISSING',
        safeMessage: 'Unauthorized',
      });
    }
    // Anonymous mode (intended for local testing only).
    // Use a stable per-client uid when provided (DEV/TEST), otherwise random.
    // NOTE: This is gated by authRequired=false; in production we keep AUTH_REQUIRED=true,
    // so this dev header is not used.
    const devUid = getDevUid(req);
    decoded = { uid: devUid ? `anon_${devUid}` : `anon_${randomUUID()}` } as any;
  } else {
    try {
      decoded = await admin.auth(getAdminApp()).verifyIdToken(bearer);
    } catch {
      throw new AppError({ status: 401, code: 'AUTH_INVALID', safeMessage: 'Unauthorized' });
    }
  }

  let appCheckToken: admin.appCheck.VerifyAppCheckTokenResponse | undefined;
  const appCheckRaw = getAppCheckToken(req);
  if (!appCheckRaw) {
    if (appCheckRequired) {
      throw new AppError({
        status: 403,
        code: 'APPCHECK_MISSING',
        safeMessage: 'App Check required',
      });
    }
  } else {
    try {
      appCheckToken = await admin.appCheck(getAdminApp()).verifyToken(appCheckRaw);
    } catch {
      throw new AppError({ status: 403, code: 'APPCHECK_INVALID', safeMessage: 'App Check invalid' });
    }
  }

  return {
    uid: decoded.uid,
    idToken: decoded,
    appCheckToken,
  };
}
