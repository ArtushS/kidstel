export class AppError extends Error {
  readonly status: number;
  readonly code: string;
  readonly safeMessage: string;

  constructor(opts: { status: number; code: string; safeMessage: string; message?: string }) {
    super(opts.message ?? opts.safeMessage);
    this.status = opts.status;
    this.code = opts.code;
    this.safeMessage = opts.safeMessage;
  }
}

export function isAppError(e: unknown): e is AppError {
  return e instanceof AppError;
}

export function toSafeErrorBody(e: unknown): { error: string; code?: string } {
  if (e instanceof AppError) {
    return { error: e.safeMessage, code: e.code };
  }
  return { error: 'Internal error' };
}
