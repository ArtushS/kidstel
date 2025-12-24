import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

extension ThemeModeExtension on ThemeMode {
  String localized(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case ThemeMode.system:
        return t.themeSystem;
      case ThemeMode.light:
        return t.themeLight;
      case ThemeMode.dark:
        return t.themeDark;
    }
  }
}
