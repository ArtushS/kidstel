# Speech-to-text languages (EN / RU / HY)

This app uses the OS speech recognition engine via the Flutter package `speech_to_text`.
It **does not** ship language packs. Supported languages depend on the device/OS engine.

## Why Armenian (hy) may stop immediately

On many devices/emulators, the speech engine may:

- Not have Armenian language packs installed/enabled.
- Be missing **Google Speech Services** (Android) or be disabled.
- Run on an emulator image **without Google Play services**, which often limits language support.
- Report “available” but fail when starting recognition with an unsupported locale.

The app now detects supported STT locales at runtime and **shows a user-friendly message** if Armenian recognition is not supported.

> Note (current behavior): the app does **not** block starting voice input based on the locale list.
> If the requested UI language locale is missing, it starts STT using **system default** recognition.

## How the app selects the STT locale

1. During initialization, the app queries supported locales from the engine:
   - Look for a log line: `STT locales: ...`
2. When you tap the mic:
   - The app chooses the best matching locale for the current app language (`en`, `ru`, `hy`).
   - If a matching locale is found (e.g. `en-*`, `ru-*`, `hy-*`), the app passes that `localeId` to the engine.
   - If no matching locale is found, the app starts STT **without** a `localeId` (system default recognition language).

### Warning / “language not supported” behavior

- The app does **not** show “language not supported” warnings when starting dictation.
- A non-fatal message may be shown only **after the session ends** if the engine produced **no recognized text**.

## How to verify supported locales

Run the app in debug mode and watch the logs:

- `STT locales: en-US, en-GB, ru-RU, ...`
- `STT start requested: appLang=hy chosenLocale=hy-AM`
- `STT status: listening / notListening / done`
- `STT error: <message> (permanent=<true/false>)`

There is also an optional on-screen debug panel (debug builds only) under the idea/mic field showing:

- current app language code
- chosen localeId
- whether Armenian is supported
- a preview of supported localeIds
- last error

## Enabling Armenian STT on Android

Steps vary by vendor/Android version, but typical paths:

1. Install/enable **Google Speech Services**:
   - Settings → Apps → (Show system apps) → **Speech Services by Google**
   - Enable it and update it in Play Store if available.
2. Enable Armenian for voice input:
   - Settings → System → Languages & input → On-screen keyboard / Voice input
   - Google voice typing / Speech Services settings → Languages
   - Add/enable **Հայերեն (Armenian)**
3. Reboot the device after adding languages (some OEMs require it).

If Armenian still isn’t available, the device’s speech engine simply may not support it.

## Recommended testing devices

- Best: a real Android phone with Google Play services and Speech Services installed.
- Emulator: use a **Google Play** system image (not “Google APIs” only) when possible.

## Notes

- The app cannot bundle STT language packs.
- The behavior depends on the installed speech recognition engine.
- When switching app languages while dictating, the app cancels listening to keep behavior predictable.

## Current dictation UX ("like ChatGPT")

- The **only** place where dictated text appears is the main idea input field
   (hint: “Type your idea or use voice”).
- During recording, the UI may show only a visual mic indicator (no separate
   preview TextField/box).
- When the session ends (auto-stop or manual stop), the app inserts the
   recognized text into the idea field **at the current cursor position**.

### Session timing

- Maximum recording duration: **10 seconds** (`listenFor: 10s`).
- Auto-stop after **3 seconds of silence** (`pauseFor: 3s`).

## AI agent prompt (RU) — reference

The following prompt text is kept here for future maintenance / handoff.

---

PROMPT ДЛЯ AI-АГЕНТА (VS Code)

Задача: довести Voice-to-Text до поведения “как в ChatGPT”

Контекст проекта

Проект: KidsTel
Flutter (VS Code), Provider, speech_to_text
VoiceInputController уже реализован и поддерживает:

system fallback по языкам

partial / final результаты

stop / cancel

пауза 3 секунды, listenFor 10 секунд

Проблемы:

распознанный текст не попадает в поле ввода идеи

создаётся временный “буфер”, но UI его не коммитит

при повторном нажатии микрофона текст не дополняется

редактор обновляется при каждом символе

ранние предупреждения “язык не поддерживается” блокируют UX

ЦЕЛЕВОЕ ПОВЕДЕНИЕ (ОБЯЗАТЕЛЬНО)

Единственное место вывода текста — поле
“Type your idea or use voice”

Во время записи:

допускается визуальный индикатор записи

текст не вставляется по словам

После окончания записи:

по авто-стопу (3 сек тишины или 10 сек лимит)

или по повторному нажатию микрофона
→ вставить финальный текст в поле

Повторное нажатие микрофона:

продолжает диктовку

текст добавляется в позицию курсора

Пользователь может:

редактировать текст вручную

после правок страница не пересобирается

Язык распознавания:

следует языку UI

если locale отсутствует → использовать system default

НЕ блокировать старт по списку locales

Сообщение “язык не поддерживается”:

показывать только если после stop нет распознанного текста

КОНКРЕТНЫЕ ШАГИ ДЛЯ АГЕНТА
1. StorySetupPage

Добавить commit-логику для VoiceInputController

Получать VoiceInputController через Provider

Отслеживать переход isListening: true → false

В этот момент:

вызвать consumeBestResult()

если текст не пуст:

вставить в _ideaTextController в позицию курсора

если пуст:

показать SnackBar (не fatal)

❗️Запрещено:

setState при каждом символе

вывод временного текста в отдельные виджеты

2. Вставка текста (utility)

Реализовать метод:

аккуратно вставляет текст в позицию курсора

добавляет пробел, если нужно

сохраняет фокус

не триггерит rebuild страницы

(использовать TextEditingValue.copyWith())

3. Кнопка микрофона

Поведение:

если !isListening → startForAppLang(appLangCode)

если isListening → stop()

❗️НЕ очищать поле ввода автоматически

4. Языки и предупреждения

НЕ показывать “язык не поддерживается” при start

warning использовать только после commit, если результат пуст

RU / HY:

если нет locale → стартовать без localeId

5. Производительность

Убрать любые rebuild-триггеры на вводе текста

VoiceController может notifyListeners,
но UI не должен пересобирать весь экран

КРИТЕРИИ ПРИЁМКИ

RU / EN работают как раньше (через system fallback)

Текст появляется только в основном поле

Повторная диктовка дописывает текст

После stop можно редактировать текст вручную

Нет “поддержка языка” до реальной ошибки

UX идентичен голосовому вводу ChatGPT

ЗАПРЕТЫ

❌ не менять архитектуру Provider

❌ не добавлять новые плагины

❌ не форсировать localeId без необходимости

❌ не добавлять отдельные TextField для partial текста
