import admin from 'firebase-admin';
import type { FieldValue, Firestore, Transaction } from 'firebase-admin/firestore';

export type AuditRecord = {
  requestId: string;
  uid: string;
  route: string;
  createdAt: FieldValue;
  blocked: boolean;
  blockReason?: string;
  storyId?: string;
};

export async function writeAudit(fs: Firestore, rec: {
  requestId: string;
  uid: string;
  route: string;
  blocked: boolean;
  blockReason?: string;
  storyId?: string;
}) {
  await fs.collection('story_audit').doc(rec.requestId).set(
    {
      requestId: rec.requestId,
      uid: rec.uid,
      route: rec.route,
      blocked: rec.blocked,
      blockReason: rec.blockReason ?? null,
      storyId: rec.storyId ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: false },
  );
}

export async function upsertStorySession(fs: Firestore, session: {
  storyId: string;
  uid: string;
  title: string;
  chapters: Array<{
    chapterIndex: number;
    title: string;
    text: string;
    progress: number;
    imageUrl?: string | null;
    choices: Array<{ id: string; label: string; payload: Record<string, any> }>;
  }>;
}) {
  await fs.collection('stories').doc(session.storyId).set(
    {
      storyId: session.storyId,
      uid: session.uid,
      title: session.title,
      chapters: session.chapters,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

export async function enforceDailyLimit(fs: Firestore, opts: { uid: string; limit: number; yyyymmdd: string }) {
  const ref = fs.collection('usage_daily').doc(`${opts.uid}_${opts.yyyymmdd}`);

  await fs.runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(ref);
    const current = (snap.exists ? (snap.data()?.count ?? 0) : 0) as number;
    if (current >= opts.limit) {
      throw new Error('DAILY_LIMIT_EXCEEDED');
    }
    tx.set(ref, { uid: opts.uid, day: opts.yyyymmdd, count: current + 1 }, { merge: true });
  });
}
