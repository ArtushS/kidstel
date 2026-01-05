'use strict';

// NOTE: Intentionally no startup logging here. This file runs on every cold start.

/**
 * Cloud Functions (Gen2) runs the Functions Framework which installs its own Express app and
 * body parsers *before* invoking our exported handler.
 *
 * If the request body contains malformed JSON with `Content-Type: application/json`, the
 * framework's JSON parser fails early and would normally return a non-JSON 400 response.
 *
 * We patch body-parser's `json()` factory via Node's `--require` preload hook so the framework
 * (and our own Express app) will respond with a stable JSON contract:
 *   HTTP 400 { ok:false, error:"invalid_json", debug:{service,revision,configuration} }
 */

function buildDebug() {
  return {
    service: process.env.K_SERVICE ?? null,
    revision: process.env.K_REVISION ?? null,
    configuration: process.env.K_CONFIGURATION ?? null,
  };
}

function patchBodyParser(bodyParser) {
  if (!bodyParser || typeof bodyParser.json !== 'function') return;
  if (bodyParser.__kidsdomInvalidJsonPatchApplied) return;

  const originalJson = bodyParser.json;

  const patchedJson = function patchedJsonFactory(...args) {
    const jsonMiddleware = originalJson.apply(this, args);

    return function patchedJsonMiddleware(req, res, next) {
      jsonMiddleware(req, res, (err) => {
        // body-parser uses `type: 'entity.parse.failed'` for JSON parse errors.
        const isParseFailed =
          err &&
          (err.type === 'entity.parse.failed' || err.name === 'SyntaxError') &&
          ((err.status && Number(err.status) === 400) ||
            (err.statusCode && Number(err.statusCode) === 400));

        if (isParseFailed && !res.headersSent) {
          res.statusCode = 400;
          res.setHeader('Content-Type', 'application/json; charset=utf-8');
          res.end(
            JSON.stringify({
              ok: false,
              error: 'invalid_json',
              debug: buildDebug(),
            })
          );
          return;
        }

        next(err);
      });
    };
  };

  // body-parser v2 exposes `json` as a getter-only property; direct assignment throws in strict mode.
  // It's configurable, so we can safely redefine it.
  try {
    Object.defineProperty(bodyParser, 'json', {
      configurable: true,
      enumerable: true,
      value: patchedJson,
    });
  } catch {
    // If redefine fails, we still mark as applied to avoid crashing in a loop.
  }

  bodyParser.__kidsdomInvalidJsonPatchApplied = true;
}

try {
  // Patch *any* body-parser instance, including nested copies used by the Functions Framework.
  // We do this by intercepting Node's module loader.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const Module = require('module');
  const originalLoad = Module._load;

  Module._load = function patchedLoad(request, parent, isMain) {
    // eslint-disable-next-line prefer-rest-params
    const loaded = originalLoad.apply(this, arguments);
    if (request === 'body-parser') {
      patchBodyParser(loaded);
    }
    return loaded;
  };

  // Also patch immediately if something already loaded it before we installed the hook.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  patchBodyParser(require('body-parser'));
} catch {
  // No-op: if we can't patch, let the runtime behave as it normally would.
}
