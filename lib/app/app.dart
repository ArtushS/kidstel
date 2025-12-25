import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';

import '../shared/settings/app_settings.dart';
import '../shared/settings/in_memory_settings_repository.dart';
import '../shared/settings/settings_controller.dart';
import '../shared/settings/settings_scope.dart';

import '../features/story/services/story_service.dart';
import 'config.dart';

class KidsTelApp extends StatefulWidget {
  const KidsTelApp({super.key});

  @override
  State<KidsTelApp> createState() => _KidsTelAppState();
}

class _KidsTelAppState extends State<KidsTelApp> {
  late final SettingsController _settings;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController(repository: InMemorySettingsRepository());
    _settings.init();
  }

  @override
  void dispose() {
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
    final router = buildRouter();

    return MultiProvider(
      providers: [
        Provider<StoryService>(
          create: (_) => StoryService(endpointUrl: storyAgentUrl),
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
              routerConfig: router,

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
