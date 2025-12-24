import 'dart:math';
import 'package:flutter/foundation.dart';

import 'models/story_view_data.dart';
import 'models/story_choice_view_data.dart';

class StoryReaderController extends ChangeNotifier {
  /// Page state
  bool isLoading = false;
  String? error;
  StoryViewData? data;

  /// UI prefs
  double textScale = 1.0;

  /// Narration (stub for now)
  bool narrationPlaying = false;

  /// Background music (stub for now)
  bool musicEnabled = false;

  /// Optional: store last chosen option
  String? lastChoiceId;

  /// Load initial story (temporary mock; next step will fetch from Cloud Function)
  Future<void> loadInitial() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      // Simulate network delay
      await Future<void>.delayed(const Duration(milliseconds: 300));

      data = StoryViewData(
        storyId: 'demo_story_001',
        title: 'Story',
        coverImageUrl: null, // put URL later
        chapterIndex: 0,
        progress: 0.1,
        text:
            'Once upon a time, in a calm forest, a little hero began an adventure.\n\n'
            'This is placeholder text. In the next step we will connect AI so this '
            'content comes from your Cloud Function.\n\n'
            'Below you can choose what happens next.',
        choices: [
          StoryChoiceViewData(
            id: 'choice_castle',
            label: 'Go to the castle',
            payload: {'next': 'castle'},
          ),
          StoryChoiceViewData(
            id: 'choice_bear',
            label: 'Talk to the friendly bear',
            payload: {'next': 'bear'},
          ),
          StoryChoiceViewData(
            id: 'choice_forest',
            label: 'Take the forest path',
            payload: {'next': 'forest'},
          ),
        ],
        isFinal: false,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Choice selected -> next chapter (mock for now)
  Future<void> onChoiceSelected(StoryChoiceViewData choice) async {
    if (isLoading) return;

    isLoading = true;
    error = null;
    lastChoiceId = choice.id;
    notifyListeners();

    try {
      // Simulate request to AI
      await Future<void>.delayed(const Duration(milliseconds: 450));

      final prev = data;
      final nextChapter = (prev?.chapterIndex ?? 0) + 1;

      // Make progress look natural for demo
      final nextProgress = min(1.0, (prev?.progress ?? 0.0) + 0.15);

      data = StoryViewData(
        storyId: prev?.storyId ?? 'demo_story_001',
        title: prev?.title ?? 'Story',
        coverImageUrl: prev?.coverImageUrl,
        chapterIndex: nextChapter,
        progress: nextProgress,
        text:
            'You chose: "${choice.label}".\n\n'
            'This is the next generated chapter (placeholder). '
            'Next step: replace this with the real Cloud Function response.\n\n'
            'Chapter $nextChapter continues the story based on the chosen path.',
        choices: _nextChoicesForDemo(nextChapter),
        isFinal: nextProgress >= 1.0,
      );

      // Auto-stop narration between chapters (stub behavior)
      narrationPlaying = false;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<StoryChoiceViewData> _nextChoicesForDemo(int chapter) {
    // After some chapters we can end demo
    if (chapter >= 4) {
      return const [];
    }

    return [
      StoryChoiceViewData(
        id: 'choice_a',
        label: 'Continue carefully',
        payload: {'next': 'carefully'},
      ),
      StoryChoiceViewData(
        id: 'choice_b',
        label: 'Ask for help',
        payload: {'next': 'help'},
      ),
      StoryChoiceViewData(
        id: 'choice_c',
        label: 'Explore something new',
        payload: {'next': 'explore'},
      ),
    ];
  }

  /// Narration control (stub for now)
  void toggleNarration() {
    // Later: call NarrationService (TTS/AI voice)
    narrationPlaying = !narrationPlaying;

    // If narration starts, apply "ducking" to music later.
    notifyListeners();
  }

  /// Music control (stub for now)
  void toggleMusic() {
    // Later: call MusicService (background audio + audio_service)
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
