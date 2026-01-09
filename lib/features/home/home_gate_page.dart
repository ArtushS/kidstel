import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/settings/settings_scope.dart';
import 'home_page.dart';

/// Gate перед Home.
///
/// Требования UX:
/// - при первом запуске (onboardingCompleted=false) после логина показать гайд
///   ДО того, как пользователь увидит Home;
/// - не допускать зацикливаний и ошибок навигации.
///
/// Здесь мы ждём загрузку настроек и затем решаем:
/// - если нужен онбординг -> отправляем на /onboarding
/// - иначе -> показываем HomePage
class HomeGatePage extends StatelessWidget {
  const HomeGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);

    if (!settings.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!settings.settings.onboardingCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.go('/onboarding');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return const HomePage();
  }
}
