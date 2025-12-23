import 'package:flutter/material.dart';

import 'router.dart';

import '../shared/settings/in_memory_settings_repository.dart';
import '../shared/settings/settings_controller.dart';
import '../shared/settings/settings_scope.dart';

// ВАЖНО: возвращаем ThemeScope, чтобы страницы не падали на ThemeScope.of(context)
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

    _themeController =
        ThemeController(); // только создаём и отдаём в ThemeScope
  }

  @override
  void dispose() {
    _settings.dispose();
    _themeController.dispose();
    super.dispose();
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
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              themeMode: _settings.settings.themeMode,
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}
