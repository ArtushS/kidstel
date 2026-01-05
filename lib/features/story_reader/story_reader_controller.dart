import 'package:flutter/foundation.dart';

import '../story/services/story_service.dart';
import '../story/services/models/generate_story_response.dart';

import 'models/story_choice_view_data.dart';
import 'models/story_view_data.dart';

class StoryReaderController extends ChangeNotifier {
  final StoryService storyService;

  // Snapshot settings for the session (needed for continue)
  final String _ageGroup; // "3_5"
  final String _storyLang; // "ru|en|hy"
  final String _storyLength; // "short|medium|long"
  final double _creativityLevel; // 0..1
  final bool _imageEnabled;

  final String _hero;
  final String _location;
  final String _style;

  bool isLoading = false;
  String? error;
  StoryViewData? data;

  double textScale = 1.0;
  bool narrationPlaying = false;
  bool musicEnabled = false;
  String? lastChoiceId;

  StoryReaderController({
    required this.storyService,
    required String ageGroup,
    required String storyLang,
    required String storyLength,
    required double creativityLevel,
    required bool imageEnabled,
    required String hero,
    required String location,
    required String style,
  }) : _ageGroup = ageGroup,
       _storyLang = storyLang,
       _storyLength = storyLength,
       _creativityLevel = creativityLevel,
       _imageEnabled = imageEnabled,
       _hero = hero,
       _location = location,
       _style = style;

  /// Use this if you open StoryReader with response from Generate
  void loadFromAgentResponse(GenerateStoryResponse resp) {
    data = _toViewData(resp);
    error = null;
    isLoading = false;
    narrationPlaying = false;
    notifyListeners();
  }

  /// If you prefer loading inside reader: pass initialBody same as in curl (action=generate)
  Future<void> loadInitial(Map<String, dynamic> initialBody) async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final json = await storyService.callAgentJson(initialBody);
      final resp = GenerateStoryResponse.fromJson(json);
      data = _toViewData(resp);
    } catch (e) {
      if (e is StoryServiceDailyLimitException ||
          e is StoryServiceCooldownException) {
        error = e.toString();
      } else {
        error = e.toString();
      }
      debugPrint('StoryReader loadInitial error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Choice selected -> agent continue -> update current page (no navigation)
  Future<void> onChoiceSelected(StoryChoiceViewData choice) async {
    final current = data;
    if (current == null || isLoading) return;

    isLoading = true;
    error = null;
    lastChoiceId = choice.id;
    notifyListeners();

    try {
      final body = <String, dynamic>{
        'action': 'continue',
        'storyId': current.storyId,
        'chapterIndex': current.chapterIndex,
        'ageGroup': _ageGroup,
        'storyLang': _storyLang,
        'storyLength': _storyLength,
        'creativityLevel': _creativityLevel,
        'image': {'enabled': _imageEnabled},
        'selection': {'hero': _hero, 'location': _location, 'style': _style},
        'choice': {
          'id': choice.id,
          'label': choice.label,
          'payload': choice.payload,
        },
      };

      final json = await storyService.callAgentJson(body);
      final resp = GenerateStoryResponse.fromJson(json);

      data = _toViewData(resp);
      narrationPlaying = false;
    } catch (e) {
      if (e is StoryServiceDailyLimitException ||
          e is StoryServiceCooldownException) {
        error = e.toString();
      } else {
        error = 'Failed to continue story: $e';
      }
      debugPrint(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  StoryViewData _toViewData(GenerateStoryResponse resp) {
    final choiceViews = resp.choices
        .where((c) => c.label.trim().isNotEmpty)
        .map(
          (c) =>
              StoryChoiceViewData(id: c.id, label: c.label, payload: c.payload),
        )
        .toList(growable: false);

    // Use image property from response
    final coverUrl = resp.image?.url;

    return StoryViewData(
      storyId: resp.storyId.isNotEmpty ? resp.storyId : 'unknown',
      title: resp.title.isNotEmpty ? resp.title : 'Story',
      coverImageUrl: coverUrl,
      chapterIndex: resp.chapterIndex,
      progress: resp.progress.clamp(0.0, 1.0),
      text: resp.text,
      choices: choiceViews,
      isFinal: choiceViews.isEmpty,
    );
  }

  void toggleNarration() {
    narrationPlaying = !narrationPlaying;
    notifyListeners();
  }

  void toggleMusic() {
    musicEnabled = !musicEnabled;
    notifyListeners();
  }

  void increaseText() {
    textScale = (textScale + 0.1).clamp(0.9, 1.6);
    notifyListeners();
  }

  void decreaseText() {
    textScale = (textScale - 0.1).clamp(0.9, 1.6);
    notifyListeners();
  }
}
