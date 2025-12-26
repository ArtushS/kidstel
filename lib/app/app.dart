import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_config.dart';
import '../auth/data/auth_service.dart';
import '../auth/data/auth_service_firebase.dart';
import '../auth/state/auth_controller.dart';
import '../firebase/firebase_bootstrap.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';

import '../shared/settings/app_settings.dart';
import '../shared/settings/shared_preferences_settings_repository.dart';
import '../shared/settings/settings_controller.dart';
import '../shared/settings/settings_scope.dart';

import '../shared/voice/voice_input_controller.dart';

import '../shared/tts/mock_tts_service.dart';
import '../shared/tts/tts_service.dart';

import '../features/story/repositories/story_repository.dart';
import '../features/story/repositories/shared_preferences_story_repository.dart';
import '../features/story/services/image_generation_service.dart';
import '../features/story/services/mock_image_generation_service.dart';

import '../features/story/services/story_service.dart';
import 'config.dart';

class KidsTelApp extends StatefulWidget {
  final FirebaseBootstrap firebaseBootstrap;

  const KidsTelApp({super.key, required this.firebaseBootstrap});

  @override
  State<KidsTelApp> createState() => _KidsTelAppState();
}

class _KidsTelAppState extends State<KidsTelApp> {
  late final SettingsController _settings;
  late final AuthService _authService;
  late final AuthController _auth;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController(
      repository: SharedPreferencesSettingsRepository(),
    );
    _settings.init();

    _authService = AuthServiceFirebase();
    _auth = AuthController(service: _authService, devBypass: kDevBypassAuth);
    _router = buildRouter(auth: _auth);
  }

  @override
  void dispose() {
    _auth.dispose();
    _settings.dispose();
    super.dispose();
  }

  double _fontFactorFromScale(FontScale s) {
    switch (s) {
      case FontScale.small:
        return 0.90;
      case FontScale.medium:
        return 1.00;
      case FontScale.large:
        return 1.15;
    }
  }

  Locale? _localeFromCode(String code) {
    switch (code) {
      case 'ru':
        return const Locale('ru');
      case 'hy':
        return const Locale('hy');
      case 'en':
      default:
        return const Locale('en');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseBootstrap>.value(value: widget.firebaseBootstrap),
        Provider<AuthService>.value(value: _authService),
        ChangeNotifierProvider<AuthController>.value(value: _auth),
        Provider<TtsService>(
          create: (_) => MockTtsService(),
          dispose: (_, tts) => tts.dispose(),
        ),
        Provider<StoryRepository>(
          create: (_) => SharedPreferencesStoryRepository(),
        ),
        Provider<ImageGenerationService>(
          create: (_) => MockImageGenerationService(),
        ),
        Provider<StoryService>(
          create: (_) => StoryService(endpointUrl: storyAgentUrl),
        ),
        ChangeNotifierProvider<VoiceInputController>(
          create: (_) => VoiceInputController()..init(),
        ),
        // другие провайдеры...
      ],
      child: SettingsScope(
        controller: _settings,
        child: AnimatedBuilder(
          animation: _settings,
          builder: (context, _) {
            final s = _settings.settings;
            final factor = _fontFactorFromScale(s.fontScale);

            return MaterialApp.router(
              debugShowCheckedModeBanner: false,

              // Theme
              themeMode: s.themeMode,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),

              // Localization
              locale: _localeFromCode(s.defaultLanguageCode),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,

              // Router
              routerConfig: _router,

              // Global font scaling
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(textScaler: TextScaler.linear(factor)),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
