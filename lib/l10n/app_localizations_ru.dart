// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get settings => 'Настройки';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get theme => 'Тема';

  @override
  String get fontSize => 'Размер шрифта';

  @override
  String get animations => 'Анимации';

  @override
  String get storyPreferences => 'Параметры истории';

  @override
  String get language => 'Язык';

  @override
  String get generate => 'Сгенерировать';

  @override
  String get createNewStory => 'Создать новую историю';

  @override
  String get describeYourIdea => 'Опиши свою идею';

  @override
  String get typeYourIdea => 'Введите идею или используйте голос…';
}
