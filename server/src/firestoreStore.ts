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
  // Optional metadata for continuity.
  lang?: string;
  ageGroup?: string;
  storyLength?: string;
  creativityLevel?: number;
  hero?: string;
  location?: string;
  style?: string;
  idea?: string;
  policyVersion?: string;
  chapters: Array<{
    chapterIndex: number;
    title: string;
    text: string;
    progress: number;
    imageUrl?: string | null;
    imageStoragePath?: string | null;
    imagePrompt?: string | null;
    choices: Array<{ id: string; label: string; payload: Record<string, any> }>;
  }>;
}) {
  await fs.collection('stories').doc(session.storyId).set(
    {
      storyId: session.storyId,
      uid: session.uid,
      title: session.title,
      lang: session.lang ?? null,
      ageGroup: session.ageGroup ?? null,
      storyLength: session.storyLength ?? null,
      creativityLevel: typeof session.creativityLevel === 'number' ? session.creativityLevel : null,
      hero: session.hero ?? null,
      location: session.location ?? null,
      style: session.style ?? null,
      idea: session.idea ?? null,
      policyVersion: session.policyVersion ?? null,
      chapters: session.chapters,
      latestChapterIndex: session.chapters.length ? session.chapters[session.chapters.length - 1].chapterIndex : 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

export type StoryMeta = {
  storyId: string;
  uid: string;
  title: string;
  lang?: string | null;
  ageGroup?: string | null;
  storyLength?: string | null;
  creativityLevel?: number | null;
  hero?: string | null;
  location?: string | null;
  style?: string | null;
  idea?: string | null;
  policyVersion?: string | null;
  latestChapterIndex?: number | null;
};

export type StoryChapterRecord = {
  chapterIndex: number;
  title: string;
  text: string;
  progress: number;
  choices: Array<{ id: string; label: string; payload: Record<string, any> }>;
  imageUrl?: string | null;
  imageStoragePath?: string | null;
  imagePrompt?: string | null;
};

export async function getStoryMeta(fs: Firestore, storyId: string): Promise<StoryMeta | null> {
  const snap = await fs.collection('stories').doc(storyId).get();
  if (!snap.exists) return null;
  const d = snap.data() as any;
  return {
    storyId: d?.storyId ?? storyId,
    uid: d?.uid ?? '',
    title: d?.title ?? '',
    lang: d?.lang ?? null,
    ageGroup: d?.ageGroup ?? null,
    storyLength: d?.storyLength ?? null,
    creativityLevel: typeof d?.creativityLevel === 'number' ? d.creativityLevel : null,
    hero: d?.hero ?? null,
    location: d?.location ?? null,
    style: d?.style ?? null,
    idea: d?.idea ?? null,
    policyVersion: d?.policyVersion ?? null,
    latestChapterIndex: typeof d?.latestChapterIndex === 'number' ? d.latestChapterIndex : null,
  };
}

export async function listStoryChapters(fs: Firestore, storyId: string, opts?: { limit?: number }): Promise<StoryChapterRecord[]> {
  const limit = Math.max(1, Math.min(10, opts?.limit ?? 4));
  try {
    const snap = await fs
      .collection('stories')
      .doc(storyId)
      .collection('chapters')
      .orderBy('chapterIndex', 'desc')
      .limit(limit)
      .get();

    const out: StoryChapterRecord[] = [];
    for (const doc of snap.docs) {
      const d = doc.data() as any;
      out.push({
        chapterIndex: Number(d?.chapterIndex ?? 0),
        title: (d?.title ?? '').toString(),
        text: (d?.text ?? '').toString(),
        progress: Number(d?.progress ?? 0),
        choices: Array.isArray(d?.choices) ? d.choices : [],
        imageUrl: d?.imageUrl ?? null,
        imageStoragePath: d?.imageStoragePath ?? null,
        imagePrompt: d?.imagePrompt ?? null,
      });
    }
    // If subcollection exists but is not populated, fall back to the story document.
    if (out.length === 0) {
      const storySnap = await fs.collection('stories').doc(storyId).get();
      const d = storySnap.exists ? (storySnap.data() as any) : null;
      const chapters = Array.isArray(d?.chapters) ? d.chapters : [];
      return chapters.slice(-limit);
    }

    // returned desc; caller often wants ascending
    return out.sort((a, b) => a.chapterIndex - b.chapterIndex);
  } catch {
    // If subcollection doesn't exist or query isn't available (tests), fall back.
    const storySnap = await fs.collection('stories').doc(storyId).get();
    const d = storySnap.exists ? (storySnap.data() as any) : null;
    const chapters = Array.isArray(d?.chapters) ? d.chapters : [];
    return chapters.slice(-limit);
  }
}

export async function getStoryChapter(fs: Firestore, storyId: string, chapterIndex: number): Promise<StoryChapterRecord | null> {
  try {
    const snap = await fs
      .collection('stories')
      .doc(storyId)
      .collection('chapters')
      .doc(String(chapterIndex))
      .get();
    if (snap.exists) {
      const d = snap.data() as any;
      return {
        chapterIndex: Number(d?.chapterIndex ?? chapterIndex),
        title: (d?.title ?? '').toString(),
        text: (d?.text ?? '').toString(),
        progress: Number(d?.progress ?? 0),
        choices: Array.isArray(d?.choices) ? d.choices : [],
        imageUrl: d?.imageUrl ?? null,
        imageStoragePath: d?.imageStoragePath ?? null,
        imagePrompt: d?.imagePrompt ?? null,
      };
    }
  } catch {
    // ignore
  }

  const storySnap = await fs.collection('stories').doc(storyId).get();
  if (!storySnap.exists) return null;
  const d = storySnap.data() as any;
  const chapters = Array.isArray(d?.chapters) ? d.chapters : [];
  const found = chapters.find((c: any) => Number(c?.chapterIndex ?? -1) === chapterIndex);
  if (!found) return null;
  return {
    chapterIndex,
    title: (found?.title ?? '').toString(),
    text: (found?.text ?? '').toString(),
    progress: Number(found?.progress ?? 0),
    choices: Array.isArray(found?.choices) ? found.choices : [],
    imageUrl: found?.imageUrl ?? null,
    imageStoragePath: found?.imageStoragePath ?? null,
    imagePrompt: found?.imagePrompt ?? null,
  };
}

export async function writeStoryChapter(fs: Firestore, opts: {
  storyId: string;
  uid: string;
  title: string;
  lang?: string;
  chapter: StoryChapterRecord;
}) {
  const storyRef = fs.collection('stories').doc(opts.storyId);
  const chRef = storyRef.collection('chapters').doc(String(opts.chapter.chapterIndex));

  await fs.runTransaction(async (tx: Transaction) => {
    const snap = await tx.get(storyRef);
    const existing = snap.exists ? (snap.data() as any) : null;
    tx.set(
      storyRef,
      {
        storyId: opts.storyId,
        uid: opts.uid,
        title: opts.title,
        lang: opts.lang ?? existing?.lang ?? null,
        latestChapterIndex: opts.chapter.chapterIndex,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: existing?.createdAt ?? admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    tx.set(
      chRef,
      {
        storyId: opts.storyId,
        chapterIndex: opts.chapter.chapterIndex,
        title: opts.chapter.title,
        text: opts.chapter.text,
        progress: opts.chapter.progress,
        choices: opts.chapter.choices,
        imageUrl: opts.chapter.imageUrl ?? null,
        imageStoragePath: opts.chapter.imageStoragePath ?? null,
        imagePrompt: opts.chapter.imagePrompt ?? null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}

export async function updateChapterIllustration(fs: Firestore, opts: {
  storyId: string;
  chapterIndex: number;
  imageUrl: string;
  imageStoragePath: string;
  imagePrompt: string;
}) {
  const chRef = fs
    .collection('stories')
    .doc(opts.storyId)
    .collection('chapters')
    .doc(String(opts.chapterIndex));

  await chRef.set(
    {
      imageUrl: opts.imageUrl,
      imageStoragePath: opts.imageStoragePath,
      imagePrompt: opts.imagePrompt,
      imageGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
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
