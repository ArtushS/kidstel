// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_page.dart';
import '../features/story_setup/story_setup_page.dart';
import '../features/reader/reader_page.dart';
import '../features/settings/settings_page.dart';
import '../shared/models/story_setup.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/setup',
      builder: (context, state) => const StorySetupPage(),
    ),
    GoRoute(
      path: '/reader',
      builder: (context, state) {
        final setup = state.extra as StorySetup?;
        return ReaderPage(setup: setup);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text('Page Not Found: ${state.uri}'))),
);
