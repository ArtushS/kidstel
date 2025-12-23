import 'package:flutter/material.dart';

import 'router.dart';

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
  late final ThemeController _themeController;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();

    _themeController = ThemeController();
    _settingsController = SettingsController(
      repository: InMemorySettingsRepository(),
    );

    // грузим настройки 1 раз при старте приложения
    _settingsController.init();

    // связка: когда меняется settings.themeMode — применяем к ThemeController
    _settingsController.addListener(_syncThemeFromSettings);
  }

  void _syncThemeFromSettings() {
    final mode = _settingsController.settings.themeMode;
    final next = switch (mode) {
      // ThemeController у тебя уже есть. Если enum у него другой — скажешь, поправлю.
      // Здесь мы переводим наши настройки в ThemeMode Flutter.
      // Если твой ThemeController хранит ThemeMode — всё ок.
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
    if (_themeController.themeMode != next) {
      _themeController.setThemeMode(next);
    }
  }

  @override
  void dispose() {
    _settingsController.removeListener(_syncThemeFromSettings);
    _settingsController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: _settingsController,
      child: ThemeScope(
        controller: _themeController,
        child: Builder(
          builder: (context) {
            final themeController = ThemeScope.of(context);
            final router = buildRouter();

            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              themeMode: themeController.themeMode,
              theme: themeController.lightTheme,
              darkTheme: themeController.darkTheme,
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}
