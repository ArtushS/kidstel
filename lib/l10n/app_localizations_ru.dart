// lib/l10n/app_localizations_ru.dart
// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

class AppLocalizationsRu extends KidsLocalizations {
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

  @override
  String get hero => 'Герой';
  @override
  String get location => 'Локация';
  @override
  String get storyType => 'Тип истории';
  @override
  String get swipeToChoose => 'Листай, чтобы выбрать';
  @override
  String get storyWillBeGenerated =>
      'История будет создана на основе твоего выбора.';
  @override
  String get generateStory => 'Создать историю';
  @override
  String get generating => 'Создание…';
  @override
  String get previewHint => 'Язык и размер шрифта можно изменить в Настройках.';
  @override
  String get loadingAssets => 'Загружаем изображения…';

  @override
  String get heroGirl => 'Девочка';
  @override
  String get heroBoy => 'Мальчик';
  @override
  String get heroRobot => 'Робот';

  @override
  String get locationForest => 'Лес';
  @override
  String get locationCity => 'Город';
  @override
  String get locationSpace => 'Космос';

  @override
  String get typeAdventure => 'Приключения';
  @override
  String get typeKindness => 'Доброта';
  @override
  String get typeFunny => 'Смешная';
}
