// lib/app/app.dart  (важная правка импорта роутера)
import 'package:flutter/material.dart';
import 'router.dart';
import '../shared/theme/theme_controller.dart';
import '../shared/theme/theme_scope.dart';

class App extends StatelessWidget {
  final ThemeController themeController;
  const App({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: themeController,
      child: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          return MaterialApp.router(
            routerConfig: router,
            themeMode: themeController.mode,
            theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
            ),
          );
        },
      ),
    );
  }
}
