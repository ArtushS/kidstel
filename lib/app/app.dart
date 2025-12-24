import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';

import '../shared/settings/app_settings.dart';
import '../shared/settings/in_memory_settings_repository.dart';
import '../shared/settings/settings_controller.dart';
import '../shared/settings/settings_scope.dart';

import '../shared/theme/theme_controller.dart';
import '../shared/theme/theme_scope.dart';

class KidsTelApp extends StatefulWidget {
  const KidsTelApp({super.key});

  @override
  State<KidsTelApp> createState() => _KidsTelAppState();
}

class _KidsTelAppState extends State<KidsTelApp> {
  late final SettingsController _settings;
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController(repository: InMemorySettingsRepository());
    _settings.init();
    _themeController = ThemeController();
  }

  @override
  void dispose() {
    _settings.dispose();
    _themeController.dispose();
    super.dispose();
  }

  double _fontFactorFromScale(FontScale s) {
    if (s == FontScale.small) return 0.90;
    if (s == FontScale.large) return 1.15;
    return 1.00; // medium
  }

  Locale _localeFromCode(String code) {
    if (code == 'ru') return const Locale('ru');
    if (code == 'hy') return const Locale('hy');
    return const Locale('en');
  }

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return SettingsScope(
      controller: _settings,
      child: ThemeScope(
        controller: _themeController,
        child: AnimatedBuilder(
          animation: _settings,
          builder: (context, _) {
            final factor = _fontFactorFromScale(_settings.settings.fontScale);
            final locale = _localeFromCode(
              _settings.settings.defaultLanguageCode,
            );

            return MaterialApp.router(
              debugShowCheckedModeBanner: false,

              // Theme
              themeMode: _settings.settings.themeMode,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),

              // Localization
              locale: locale,
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
