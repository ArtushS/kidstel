import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../features/home/home_page.dart';
import '../features/story_setup/story_setup_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/voice_help_page.dart';
import '../shared/models/story_setup.dart';
import '../features/story_reader/story_reader_args.dart';
import '../features/story_reader/story_reader_page.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => const MaterialPage(child: HomePage()),
      ),
      GoRoute(
        path: '/setup',
        pageBuilder: (context, state) =>
            const MaterialPage(child: StorySetupPage()),
      ),
      GoRoute(
        path: '/reader',
        pageBuilder: (context, state) =>
            const MaterialPage(child: StoryReaderPage()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            const MaterialPage(child: SettingsPage()),
      ),
      GoRoute(
        path: '/voice-help',
        pageBuilder: (context, state) =>
            const MaterialPage(child: VoiceHelpPage()),
      ),
      GoRoute(
        path: '/story-reader',
        name: 'story-reader',
        builder: (context, state) {
          final extra = state.extra;
          final setup = extra is StorySetup ? extra : null;

          // StorySetupPage currently navigates with a Map payload.
          final map = extra is Map ? extra : null;
          final args = StoryReaderArgs(
            initialResponse: map?['response'],
            ageGroup: (map?['ageGroup'] ?? setup?.ageGroup ?? '') as String,
            storyLang: (map?['lang'] ?? setup?.storyLang ?? '') as String,
            storyLength: (map?['length'] ?? setup?.storyLength ?? '') as String,
            creativityLevel:
                (map?['creativity'] ?? setup?.creativityLevel ?? 0.5) as double,
            imageEnabled:
                (map?['imageEnabled'] ?? setup?.imageEnabled ?? false) as bool,
            hero: (map?['hero'] ?? setup?.hero ?? '') as String,
            location: (map?['location'] ?? setup?.location ?? '') as String,
            style: (map?['style'] ?? setup?.style ?? '') as String,
          );

          return StoryReaderPage(args: args);
        },
      ),
    ],
    errorPageBuilder: (context, state) {
      return MaterialPage(
        child: Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.of(context)!.notFound)),
          body: Center(child: Text(state.error.toString())),
        ),
      );
    },
  );
}
