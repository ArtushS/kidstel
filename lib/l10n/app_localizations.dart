import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hy.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hy'),
    Locale('ru'),
  ];

  /// No description provided for @createStory.
  ///
  /// In en, this message translates to:
  /// **'Create Story'**
  String get createStory;

  /// No description provided for @myStories.
  ///
  /// In en, this message translates to:
  /// **'My Stories'**
  String get myStories;

  /// No description provided for @hero.
  ///
  /// In en, this message translates to:
  /// **'Hero'**
  String get hero;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @swipeToChoose.
  ///
  /// In en, this message translates to:
  /// **'Swipe to choose'**
  String get swipeToChoose;

  /// No description provided for @heroBear.
  ///
  /// In en, this message translates to:
  /// **'Bear'**
  String get heroBear;

  /// No description provided for @heroCat.
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get heroCat;

  /// No description provided for @heroDog.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get heroDog;

  /// Hero option label shown in the hero carousel (boy).
  ///
  /// In en, this message translates to:
  /// **'Boy'**
  String get heroBoy;

  /// Hero option label shown in the hero carousel (girl).
  ///
  /// In en, this message translates to:
  /// **'Girl'**
  String get heroGirl;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @animations.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get animations;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion if disabled'**
  String get reduceMotion;

  /// No description provided for @storyPreferences.
  ///
  /// In en, this message translates to:
  /// **'Story preferences'**
  String get storyPreferences;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @ageGroup.
  ///
  /// In en, this message translates to:
  /// **'Age group'**
  String get ageGroup;

  /// No description provided for @storyLength.
  ///
  /// In en, this message translates to:
  /// **'Story length'**
  String get storyLength;

  /// No description provided for @complexity.
  ///
  /// In en, this message translates to:
  /// **'Complexity'**
  String get complexity;

  /// No description provided for @defaultNarrationVoice.
  ///
  /// In en, this message translates to:
  /// **'Default narration voice'**
  String get defaultNarrationVoice;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @voiceNarration.
  ///
  /// In en, this message translates to:
  /// **'Voice narration'**
  String get voiceNarration;

  /// No description provided for @backgroundMusic.
  ///
  /// In en, this message translates to:
  /// **'Background music'**
  String get backgroundMusic;

  /// No description provided for @soundEffects.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get soundEffects;

  /// No description provided for @autoPlayNarration.
  ///
  /// In en, this message translates to:
  /// **'Auto-play narration'**
  String get autoPlayNarration;

  /// No description provided for @parentalSafety.
  ///
  /// In en, this message translates to:
  /// **'Parental & Safety'**
  String get parentalSafety;

  /// No description provided for @safeMode.
  ///
  /// In en, this message translates to:
  /// **'Safe mode'**
  String get safeMode;

  /// No description provided for @restrictsSensitiveContent.
  ///
  /// In en, this message translates to:
  /// **'Restricts sensitive content'**
  String get restrictsSensitiveContent;

  /// No description provided for @disableScaryContent.
  ///
  /// In en, this message translates to:
  /// **'Disable scary content'**
  String get disableScaryContent;

  /// No description provided for @requireParentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Require parent confirmation'**
  String get requireParentConfirmation;

  /// No description provided for @beforeStoryGeneration.
  ///
  /// In en, this message translates to:
  /// **'Before story generation'**
  String get beforeStoryGeneration;

  /// No description provided for @aiGeneration.
  ///
  /// In en, this message translates to:
  /// **'AI & Generation'**
  String get aiGeneration;

  /// No description provided for @autoGenerateIllustrations.
  ///
  /// In en, this message translates to:
  /// **'Auto-generate illustrations'**
  String get autoGenerateIllustrations;

  /// No description provided for @creativityLevel.
  ///
  /// In en, this message translates to:
  /// **'Creativity level'**
  String get creativityLevel;

  /// No description provided for @rememberPreferences.
  ///
  /// In en, this message translates to:
  /// **'Remember preferences'**
  String get rememberPreferences;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @resetSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get resetSettings;

  /// No description provided for @backToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Back to defaults'**
  String get backToDefaults;

  /// No description provided for @resetSettingsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Reset settings?'**
  String get resetSettingsQuestion;

  /// No description provided for @restoreDefaultsMessage.
  ///
  /// In en, this message translates to:
  /// **'This will restore all settings to default values.'**
  String get restoreDefaultsMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @fontSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get fontSmall;

  /// No description provided for @fontMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get fontMedium;

  /// No description provided for @fontLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get fontLarge;

  /// No description provided for @age3to5.
  ///
  /// In en, this message translates to:
  /// **'3–5'**
  String get age3to5;

  /// No description provided for @age6to8.
  ///
  /// In en, this message translates to:
  /// **'6–8'**
  String get age6to8;

  /// No description provided for @age9to12.
  ///
  /// In en, this message translates to:
  /// **'9–12'**
  String get age9to12;

  /// No description provided for @storyShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get storyShort;

  /// No description provided for @storyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get storyMedium;

  /// No description provided for @storyLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get storyLong;

  /// No description provided for @complexitySimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get complexitySimple;

  /// No description provided for @complexityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get complexityNormal;

  /// No description provided for @creativityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get creativityLow;

  /// No description provided for @creativityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get creativityNormal;

  /// No description provided for @creativityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get creativityHigh;

  /// No description provided for @createNewStory.
  ///
  /// In en, this message translates to:
  /// **'Create new story'**
  String get createNewStory;

  /// No description provided for @describeYourIdea.
  ///
  /// In en, this message translates to:
  /// **'Describe your idea'**
  String get describeYourIdea;

  /// No description provided for @typeYourIdea.
  ///
  /// In en, this message translates to:
  /// **'Type your idea or use voice…'**
  String get typeYourIdea;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @storyGeneratedFromIdea.
  ///
  /// In en, this message translates to:
  /// **'Story will be generated from your idea'**
  String get storyGeneratedFromIdea;

  /// No description provided for @heroFox.
  ///
  /// In en, this message translates to:
  /// **'Fox'**
  String get heroFox;

  /// No description provided for @heroRabbit.
  ///
  /// In en, this message translates to:
  /// **'Rabbit'**
  String get heroRabbit;

  /// No description provided for @heroDice.
  ///
  /// In en, this message translates to:
  /// **'Dice'**
  String get heroDice;

  /// No description provided for @heroRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get heroRandom;

  /// No description provided for @locationCastle.
  ///
  /// In en, this message translates to:
  /// **'Castle'**
  String get locationCastle;

  /// No description provided for @locationCozyCottage.
  ///
  /// In en, this message translates to:
  /// **'Cozy cottage'**
  String get locationCozyCottage;

  /// No description provided for @locationFloatingIsland.
  ///
  /// In en, this message translates to:
  /// **'Floating island'**
  String get locationFloatingIsland;

  /// No description provided for @locationSnowCastle.
  ///
  /// In en, this message translates to:
  /// **'Snow castle'**
  String get locationSnowCastle;

  /// No description provided for @locationUnderwater.
  ///
  /// In en, this message translates to:
  /// **'Underwater'**
  String get locationUnderwater;

  /// No description provided for @locationRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get locationRandom;

  /// Label for the 'random location' option in the location carousel.
  ///
  /// In en, this message translates to:
  /// **'Random location'**
  String get randomLocationLabel;

  /// No description provided for @storyType.
  ///
  /// In en, this message translates to:
  /// **'Story Type'**
  String get storyType;

  /// Label for the 'random style' option in the style carousel.
  ///
  /// In en, this message translates to:
  /// **'Random style'**
  String get randomStyleLabel;

  /// No description provided for @typeFriendly.
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get typeFriendly;

  /// No description provided for @typeAdventure.
  ///
  /// In en, this message translates to:
  /// **'Adventure'**
  String get typeAdventure;

  /// No description provided for @typeMagic.
  ///
  /// In en, this message translates to:
  /// **'Magic'**
  String get typeMagic;

  /// No description provided for @typeFunny.
  ///
  /// In en, this message translates to:
  /// **'Funny'**
  String get typeFunny;

  /// No description provided for @typeRomantic.
  ///
  /// In en, this message translates to:
  /// **'Romantic'**
  String get typeRomantic;

  /// No description provided for @toggleDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Toggle dark mode'**
  String get toggleDarkMode;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @voiceInput.
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get voiceInput;

  /// Short informational label shown under the idea input on Create New Story page.
  ///
  /// In en, this message translates to:
  /// **'TTS: system'**
  String get ttsSystemLabel;

  /// Settings field label for an optional child name.
  ///
  /// In en, this message translates to:
  /// **'Child name'**
  String get childNameLabel;

  /// Settings field hint for an optional child name.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get childNameHint;

  /// Settings field label for an optional hero name (used as the main character's name when generating stories).
  ///
  /// In en, this message translates to:
  /// **'Hero name'**
  String get heroNameLabel;

  /// Settings field hint for an optional hero name.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get heroNameHint;

  /// Short helper text shown above the hero name input in Settings.
  ///
  /// In en, this message translates to:
  /// **'If set, the story will use this name for the main hero.'**
  String get heroNameHelper;

  /// No description provided for @voiceHelpTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice input help'**
  String get voiceHelpTitle;

  /// No description provided for @voiceHelpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Armenian voice input & languages'**
  String get voiceHelpSubtitle;

  /// No description provided for @voiceHelpArmenianTitle.
  ///
  /// In en, this message translates to:
  /// **'Armenian voice input'**
  String get voiceHelpArmenianTitle;

  /// No description provided for @voiceHelpStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Supported on this device'**
  String get voiceHelpStatusLabel;

  /// No description provided for @voiceHelpSupportedYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get voiceHelpSupportedYes;

  /// No description provided for @voiceHelpSupportedNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get voiceHelpSupportedNo;

  /// No description provided for @voiceHelpSupportedHint.
  ///
  /// In en, this message translates to:
  /// **'Armenian voice input appears to be supported. Tap the mic and try a short phrase.'**
  String get voiceHelpSupportedHint;

  /// No description provided for @voiceHelpSteps.
  ///
  /// In en, this message translates to:
  /// **'Voice input depends on your phone\'s speech services and language settings. The app can\'t enable it automatically.\n\nTry: Settings → Language & input → Voice input (or Google voice typing) → Languages → enable Armenian.'**
  String get voiceHelpSteps;

  /// No description provided for @voiceNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Voice input not available'**
  String get voiceNotAvailable;

  /// No description provided for @voiceNotAvailableHyMessage.
  ///
  /// In en, this message translates to:
  /// **'Armenian speech recognition is not supported on this device. You can still type Armenian with the keyboard and it will be sent to AI.'**
  String get voiceNotAvailableHyMessage;

  /// No description provided for @voiceHelpWhatIsThis.
  ///
  /// In en, this message translates to:
  /// **'What is this?'**
  String get voiceHelpWhatIsThis;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @openSettingsManually.
  ///
  /// In en, this message translates to:
  /// **'Open settings manually: Settings → Language & input → Voice input'**
  String get openSettingsManually;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @generateRequestMVP.
  ///
  /// In en, this message translates to:
  /// **'Generate request (MVP)'**
  String get generateRequestMVP;

  /// Button label while story generation is in progress.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get generating;

  /// Dialog title shown when story generation fails.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get generationFailedTitle;

  /// Snackbar text shown when speech recognition ends with empty result.
  ///
  /// In en, this message translates to:
  /// **'Speech recognition produced no results'**
  String get sttNoResults;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @reading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// No description provided for @noStoryYet.
  ///
  /// In en, this message translates to:
  /// **'No story yet'**
  String get noStoryYet;

  /// No description provided for @noStoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Create Story\" on the main page to create a new story.'**
  String get noStoryMessage;

  /// No description provided for @chapter1.
  ///
  /// In en, this message translates to:
  /// **'Chapter 1'**
  String get chapter1;

  /// No description provided for @choicePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choice (placeholder):'**
  String get choicePlaceholder;

  /// No description provided for @goLeft.
  ///
  /// In en, this message translates to:
  /// **'Go left'**
  String get goLeft;

  /// No description provided for @goRight.
  ///
  /// In en, this message translates to:
  /// **'Go right'**
  String get goRight;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @notFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notFound;

  /// No description provided for @story.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get story;

  /// No description provided for @chooseWhatNext.
  ///
  /// In en, this message translates to:
  /// **'Choose what happens next:'**
  String get chooseWhatNext;

  /// No description provided for @readAloud.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get readAloud;

  /// No description provided for @stopReading.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopReading;

  /// No description provided for @illustration.
  ///
  /// In en, this message translates to:
  /// **'Illustration'**
  String get illustration;

  /// No description provided for @generateImage.
  ///
  /// In en, this message translates to:
  /// **'Generate image'**
  String get generateImage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @saveToMyStories.
  ///
  /// In en, this message translates to:
  /// **'Save to My Stories'**
  String get saveToMyStories;

  /// No description provided for @interactiveStories.
  ///
  /// In en, this message translates to:
  /// **'Enable interactive stories'**
  String get interactiveStories;

  /// No description provided for @interactiveStoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show choices (up to 3 steps) to continue the story'**
  String get interactiveStoriesSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hy', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hy':
      return AppLocalizationsHy();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
