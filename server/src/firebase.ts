import admin from 'firebase-admin';
import { logger } from './logging.js';

let app: admin.app.App | null = null;

export function getAdminApp(projectId: string): admin.app.App {
  if (app) return app;

  // Cloud Run: use Application Default Credentials.
  app = admin.initializeApp({
    projectId,
  });

  logger.info({ projectId }, 'firebase-admin initialized');
  return app;
}

export function getFirestore(projectId: string, databaseId: string) {
  const a = getAdminApp(projectId);
  const fs = admin.firestore(a);
  // databaseId currently not switchable in firebase-admin for Firestore; kept for future.
  void databaseId;
  return fs;
}
