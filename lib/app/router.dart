import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_page.dart';
import '../features/story_setup/story_setup_page.dart';
import '../features/reader/reader_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/models/story_setup.dart';

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
        pageBuilder: (context, state) {
          final extra = state.extra;
          final setup = extra is StorySetup ? extra : null;
          return MaterialPage(child: ReaderPage(setup: setup));
        },
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) =>
            const MaterialPage(child: SettingsPage()),
      ),
    ],
    errorPageBuilder: (context, state) {
      return MaterialPage(
        child: Scaffold(
          appBar: AppBar(title: const Text('Not found')),
          body: Center(child: Text(state.error.toString())),
        ),
      );
    },
  );
}
