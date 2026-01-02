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
    // Anonymous mode (intended for local testing only)
    decoded = { uid: `anon_${randomUUID()}` } as any;
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
