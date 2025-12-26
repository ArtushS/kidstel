import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../auth/state/auth_controller.dart';
import '../auth/state/auth_state.dart';
import '../auth/presentation/auth_gate.dart';
import '../auth/presentation/login_page.dart';
import '../auth/presentation/register_page.dart';
import '../auth/presentation/forgot_password_page.dart';
import '../auth/presentation/reset_password_sent_page.dart';
import '../auth/presentation/account_page.dart';
import '../auth/presentation/change_password_page.dart';
import '../auth/presentation/provider_link_page.dart';
import '../features/home/home_page.dart';
import '../features/story_setup/story_setup_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/voice_help_page.dart';
import '../features/my_stories/my_stories_page.dart';
import '../shared/models/story_setup.dart';
import '../features/story_reader/story_reader_args.dart';
import '../features/story_reader/story_reader_page.dart';

GoRouter buildRouter({required AuthController auth}) {
  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.uri.path;

    const authRoutes = <String>{
      '/auth',
      '/login',
      '/register',
      '/forgot-password',
      '/reset-sent',
    };

    final isAuthRoute = authRoutes.contains(loc);
    final status = auth.state.status;

    if (status == AuthStatus.unknown || status == AuthStatus.loading) {
      return loc == '/auth' ? null : '/auth';
    }

    if (status == AuthStatus.unauthenticated) {
      if (auth.devBypass) {
        // DEV: auto anonymous sign-in happens in controller.
        return loc == '/auth' ? null : '/auth';
      }
      // PROD: allow only auth flow routes.
      return isAuthRoute ? null : '/login';
    }

    if (status == AuthStatus.authenticated) {
      // Keep authenticated users out of auth flow.
      return isAuthRoute || loc == '/auth' ? '/' : null;
    }

    return null;
  }

  return GoRouter(
    initialLocation: '/auth',
    refreshListenable: auth,
    redirect: redirect,
    routes: [
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => const MaterialPage(child: AuthGate()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const MaterialPage(child: LoginPage()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) =>
            const MaterialPage(child: RegisterPage()),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/reset-sent',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ResetPasswordSentPage()),
      ),
      GoRoute(
        path: '/account',
        pageBuilder: (context, state) =>
            const MaterialPage(child: AccountPage()),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ChangePasswordPage()),
      ),
      GoRoute(
        path: '/provider-link',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ProviderLinkPage()),
      ),
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
            const MaterialPage(child: MyStoriesPage()),
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
            restoreStoryId: map?['storyId']?.toString(),
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
