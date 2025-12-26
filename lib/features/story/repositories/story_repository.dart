import '../models/story_state.dart';

abstract class StoryRepository {
  Future<void> upsert(StoryState story);

  Future<StoryState?> getById(String storyId);

  Future<List<StoryState>> listAll();

  Future<void> delete(String storyId);
}
