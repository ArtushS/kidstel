import pino from 'pino';
import pinoHttp from 'pino-http';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  // Defense-in-depth: if a log line ever includes request headers, redact tokens.
  redact: {
    paths: [
      // Common placements (pino-http + express)
      'req.headers.authorization',
      'req.headers.x-firebase-appcheck',
      'req.headers.cookie',
      'req.headers.set-cookie',
      // Sometimes user code logs a plain headers object
      'headers.authorization',
      'headers.x-firebase-appcheck',
      'headers.cookie',
      'headers.set-cookie',
      // AppCheck / Auth could also appear nested in error contexts
      '*.headers.authorization',
      '*.headers.x-firebase-appcheck',
    ],
    censor: '[REDACTED]',
  },
});

export const httpLogger = pinoHttp({
  logger,
  // Never log headers or bodies. Keep access logs metadata-only.
  customProps(req, res) {
    const body = (req as any)?.body;
    const bodyObj = body && typeof body === 'object' && !Array.isArray(body) ? (body as any) : null;
    const requestIdFromBody =
      bodyObj && typeof bodyObj.requestId === 'string' && bodyObj.requestId.trim() ? bodyObj.requestId.trim() : null;
    const requestIdFromLocals =
      (res as any)?.locals && typeof (res as any).locals.requestId === 'string' && (res as any).locals.requestId.trim()
        ? (res as any).locals.requestId.trim()
        : null;

    const actionRaw = bodyObj ? (bodyObj.action ?? '').toString().trim().toLowerCase() : '';

    return {
      requestId: requestIdFromLocals ?? requestIdFromBody,
      action: actionRaw || undefined,
    };
  },
  serializers: {
    req(req) {
      return {
        id: (req as any).id,
        method: req.method,
        url: req.url,
        remoteAddress: (req as any).remoteAddress,
        remotePort: (req as any).remotePort,
      };
    },
    res(res) {
      return {
        statusCode: (res as any).statusCode,
      };
    },
  },
  customSuccessMessage: function () {
    return 'request completed';
  },
});
