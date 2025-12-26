import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../models/story_state.dart';
import 'story_repository.dart';

/// Firestore-backed repository (prep work).
///
/// This does NOT replace the current SharedPreferences repository yet.
/// It is safe to inject in parallel and switch later.
class FirestoreStoryRepository implements StoryRepository {
  final FirebaseFirestore _db;
  final fb.FirebaseAuth _auth;

  FirestoreStoryRepository({FirebaseFirestore? db, fb.FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? fb.FirebaseAuth.instance;

  String _uidOrThrow() {
    final u = _auth.currentUser;
    final uid = u?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Not authenticated (uid is null).');
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _storiesCol(String uid) {
    return _db.collection('users').doc(uid).collection('stories');
  }

  @override
  Future<void> upsert(StoryState story) async {
    final uid = _uidOrThrow();
    await _storiesCol(uid).doc(story.storyId).set({
      ...story.toJson(),
      // Helpful for ordering in Firestore; not required by the app.
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<StoryState?> getById(String storyId) async {
    final uid = _uidOrThrow();
    final doc = await _storiesCol(uid).doc(storyId).get();
    final data = doc.data();
    if (data == null) return null;
    return StoryState.fromJson(data);
  }

  @override
  Future<List<StoryState>> listAll() async {
    final uid = _uidOrThrow();
    final snap = await _storiesCol(uid).get();
    final stories = snap.docs
        .map((d) => StoryState.fromJson(d.data()))
        .toList(growable: false);

    stories.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return stories;
  }

  @override
  Future<void> delete(String storyId) async {
    final uid = _uidOrThrow();
    await _storiesCol(uid).doc(storyId).delete();
  }
}
