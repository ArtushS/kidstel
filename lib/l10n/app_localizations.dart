// lib/l10n/app_localizations.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hy.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

abstract class KidsLocalizations {
  KidsLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static KidsLocalizations? of(BuildContext context) {
    return Localizations.of<KidsLocalizations>(context, KidsLocalizations);
  }

  static const LocalizationsDelegate<KidsLocalizations> delegate =
      _KidsLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hy'),
    Locale('ru'),
  ];

  // Existing keys
  String get settings;
  String get appearance;
  String get theme;
  String get fontSize;
  String get animations;
  String get storyPreferences;
  String get language;
  String get generate;
  String get createNewStory;
  String get describeYourIdea;
  String get typeYourIdea;

  // StorySetup keys
  String get hero;
  String get location;
  String get storyType;
  String get swipeToChoose;
  String get storyWillBeGenerated;
  String get generateStory;
  String get generating;
  String get previewHint;
  String get loadingAssets;

  String get heroGirl;
  String get heroBoy;
  String get heroRobot;

  String get locationForest;
  String get locationCity;
  String get locationSpace;

  String get typeAdventure;
  String get typeKindness;
  String get typeFunny;
}

class _KidsLocalizationsDelegate
    extends LocalizationsDelegate<KidsLocalizations> {
  const _KidsLocalizationsDelegate();

  @override
  Future<KidsLocalizations> load(Locale locale) {
    return SynchronousFuture<KidsLocalizations>(
      lookupKidsLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hy', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_KidsLocalizationsDelegate old) => false;
}

KidsLocalizations lookupKidsLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hy':
      return AppLocalizationsHy();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'KidsLocalizations.delegate failed to load unsupported locale "$locale".',
  );
}
