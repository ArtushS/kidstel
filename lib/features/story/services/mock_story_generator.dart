import 'dart:math';

import '../../../shared/models/family_profile.dart';

class MockStoryGenerator {
  final Map<String, _MockStoryPlan> _plans = <String, _MockStoryPlan>{};
  final Random _rand = Random();

  Map<String, dynamic> generate(Map<String, dynamic> body) {
    final action = (body['action'] ?? '').toString().trim().toLowerCase();
    if (action == 'generate') {
      return _handleGenerate(body);
    }
    if (action == 'continue') {
      return _handleContinue(body);
    }
    if (action == 'illustrate') {
      return <String, dynamic>{
        'requestId': _requestId(),
        'image': <String, dynamic>{
          'enabled': false,
          'disabled': true,
          'reason': 'mock',
        },
      };
    }
    throw Exception('Unsupported action: $action');
  }

  Map<String, dynamic> _handleGenerate(Map<String, dynamic> body) {
    final storyId = _newStoryId();
    final plan = _createPlan(body, storyId: storyId);
    _plans[storyId] = plan;
    return _buildResponse(
      plan,
      chapterIndex: 0,
      lastChoiceLabel: null,
      requestId: _requestId(),
    );
  }

  Map<String, dynamic> _handleContinue(Map<String, dynamic> body) {
    final storyId = (body['storyId'] ?? '').toString().trim();
    if (storyId.isEmpty) {
      throw Exception('Missing storyId for continue');
    }

    final plan = _plans[storyId] ?? _createPlan(body, storyId: storyId);
    _plans[storyId] = plan;

    final rawIndex = body['chapterIndex'];
    final chapterIndex = (rawIndex is num)
        ? rawIndex.toInt() + 1
        : (int.tryParse(rawIndex?.toString() ?? '') ?? 0) + 1;

    final choice = body['choice'];
    final lastChoiceLabel = (choice is Map)
        ? (choice['label']?.toString().trim() ?? '')
        : '';
    if (lastChoiceLabel.isNotEmpty) {
      plan.pickedChoices.add(lastChoiceLabel);
    }

    return _buildResponse(
      plan,
      chapterIndex: chapterIndex.clamp(0, plan.totalChapters - 1),
      lastChoiceLabel: lastChoiceLabel.isEmpty ? null : lastChoiceLabel,
      requestId: _requestId(),
    );
  }

  String _newStoryId() {
    final t = DateTime.now().toUtc().microsecondsSinceEpoch;
    final r = _rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'mock_${t}_$r';
  }

  String _requestId() {
    final t = DateTime.now().toUtc().microsecondsSinceEpoch;
    final r = _rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'req_${t}_$r';
  }

  _MockStoryPlan _createPlan(
    Map<String, dynamic> body, {
    required String storyId,
  }) {
    final selection = body['selection'] is Map
        ? Map<String, dynamic>.from(body['selection'] as Map)
        : const <String, dynamic>{};

    final hero = (selection['hero'] ?? '').toString().trim();
    final location = (selection['location'] ?? '').toString().trim();
    final style = (selection['style'] ?? '').toString().trim();
    final storyLang = (body['storyLang'] ?? 'en')
        .toString()
        .trim()
        .toLowerCase();
    final storyLength = (body['storyLength'] ?? 'medium')
        .toString()
        .trim()
        .toLowerCase();
    final idea = (body['idea'] ?? '').toString().trim();

    final family = _familyFromBody(body);

    final totalChapters = switch (storyLength) {
      'short' => 3,
      'long' => 6,
      _ => 4,
    };

    final cast = _buildCast(storyLang: storyLang, hero: hero, family: family);

    final locationLabel = location.isNotEmpty
        ? location
        : _defaultLocation(storyLang);
    final styleLabel = style.isNotEmpty ? style : _defaultStyle(storyLang);

    final title = _titleFor(
      lang: storyLang,
      family: family,
      hero: cast.mainHero,
      location: locationLabel,
    );

    final summary = _summaryFor(
      lang: storyLang,
      hero: cast.mainHero,
      companion: cast.companion,
      location: locationLabel,
      style: styleLabel,
      idea: idea,
    );

    final choiceChapters = _pickChoiceChapters(totalChapters);

    return _MockStoryPlan(
      storyId: storyId,
      title: title,
      summary: summary,
      totalChapters: totalChapters,
      storyLang: storyLang,
      hero: cast.mainHero,
      companion: cast.companion,
      location: locationLabel,
      style: styleLabel,
      family: family,
      choiceChapters: choiceChapters,
      pickedChoices: <String>[],
    );
  }

  List<int> _pickChoiceChapters(int total) {
    if (total <= 3) return const <int>[0, 1];
    if (total == 4) return const <int>[0, 1, 2];
    return const <int>[1, 3, 4];
  }

  Map<String, dynamic> _buildResponse(
    _MockStoryPlan plan, {
    required int chapterIndex,
    required String? lastChoiceLabel,
    required String requestId,
  }) {
    final idx = chapterIndex.clamp(0, plan.totalChapters - 1);
    final progress = ((idx + 1) / plan.totalChapters).clamp(0.0, 1.0);
    final chapterTitle = _chapterTitle(plan.storyLang, idx + 1);

    final text = _chapterText(
      plan: plan,
      chapterIndex: idx,
      lastChoiceLabel: lastChoiceLabel,
    );

    final choices = plan.choiceChapters.contains(idx)
        ? _buildChoices(plan: plan, chapterIndex: idx)
        : const <Map<String, dynamic>>[];

    return <String, dynamic>{
      'requestId': requestId,
      'storyId': plan.storyId,
      'chapterIndex': idx,
      'progress': progress,
      'title': plan.title,
      'chapterTitle': chapterTitle,
      'text': text,
      'image': <String, dynamic>{'enabled': false},
      'choices': choices,
    };
  }

  List<Map<String, dynamic>> _buildChoices({
    required _MockStoryPlan plan,
    required int chapterIndex,
  }) {
    final labels = _choiceLabels(
      lang: plan.storyLang,
      location: plan.location,
      style: plan.style,
      companion: plan.companion,
    );

    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < labels.length; i++) {
      out.add({
        'id': 'c${chapterIndex}_${i + 1}',
        'label': labels[i],
        'payload': <String, dynamic>{'path': 'p${i + 1}'},
      });
    }
    return out;
  }

  String _chapterText({
    required _MockStoryPlan plan,
    required int chapterIndex,
    required String? lastChoiceLabel,
  }) {
    final isFirst = chapterIndex == 0;
    final isLast = chapterIndex >= plan.totalChapters - 1;

    final intro = _introLine(
      lang: plan.storyLang,
      hero: plan.hero,
      companion: plan.companion,
      location: plan.location,
    );

    final choiceLine = lastChoiceLabel == null || lastChoiceLabel.isEmpty
        ? ''
        : _choiceLine(plan.storyLang, lastChoiceLabel);

    final mid = _middleLine(
      lang: plan.storyLang,
      style: plan.style,
      family: plan.family,
    );

    final ending = _endingLine(plan.storyLang, isLast: isLast);

    final summaryLine = isFirst
        ? _summaryLine(plan.storyLang, plan.summary)
        : '';

    final parts = <String>[
      if (summaryLine.isNotEmpty) summaryLine,
      intro,
      if (choiceLine.isNotEmpty) choiceLine,
      mid,
      ending,
    ];

    return parts.where((e) => e.trim().isNotEmpty).join('\n\n');
  }

  String _summaryLine(String lang, String summary) {
    if (summary.trim().isEmpty) return '';
    if (lang == 'ru') return 'Кратко: $summary';
    if (lang == 'hy') return 'Կարճ՝ $summary';
    return 'Summary: $summary';
  }

  String _introLine({
    required String lang,
    required String hero,
    required String companion,
    required String location,
  }) {
    if (lang == 'ru') {
      return '$hero и $companion отправились в $location, чтобы найти удивительное приключение.';
    }
    if (lang == 'hy') {
      return '$hero և $companion գնացին $location՝ հետաքրքիր արկածի որոնման։';
    }
    return '$hero and $companion went to $location to find a new adventure.';
  }

  String _middleLine({
    required String lang,
    required String style,
    required FamilyProfile? family,
  }) {
    final familyHint = _familyHint(lang, family);
    if (lang == 'ru') {
      return 'Дорога была в стиле "$style". $familyHint';
    }
    if (lang == 'hy') {
      return 'Ճանապարհը "$style" ոճով էր։ $familyHint';
    }
    return 'The journey felt like "$style". $familyHint';
  }

  String _familyHint(String lang, FamilyProfile? family) {
    if (family == null || !family.enabled) return '';
    final names = _familyNames(family);
    if (names.isEmpty) return '';
    final list = names.join(', ');
    if (lang == 'ru') return 'Рядом были: $list.';
    if (lang == 'hy') return 'Կողքին էին՝ $list։';
    return 'Nearby were: $list.';
  }

  String _choiceLine(String lang, String choiceLabel) {
    if (lang == 'ru') return 'Они выбрали: $choiceLabel.';
    if (lang == 'hy') return 'Նրանք ընտրեցին՝ $choiceLabel։';
    return 'They chose: $choiceLabel.';
  }

  String _endingLine(String lang, {required bool isLast}) {
    if (!isLast) {
      if (lang == 'ru') return 'История продолжается...';
      if (lang == 'hy') return 'Պատմությունը շարունակվում է...';
      return 'The story continues...';
    }
    if (lang == 'ru') return 'Так закончилась эта добрая история.';
    if (lang == 'hy') return 'Այսպիսով ավարտվեց այս բարի պատմությունը։';
    return 'And that is how this kind story ended.';
  }

  String _chapterTitle(String lang, int number) {
    if (lang == 'ru') return 'Глава $number';
    if (lang == 'hy') return 'Գլուխ $number';
    return 'Chapter $number';
  }

  String _titleFor({
    required String lang,
    required FamilyProfile? family,
    required String hero,
    required String location,
  }) {
    if (family != null && family.enabled) {
      if (lang == 'ru') return 'Семейная история про $hero';
      if (lang == 'hy') return '$hero ընտանիքի պատմություն';
      return 'A family story about $hero';
    }
    if (lang == 'ru') return 'История про $hero';
    if (lang == 'hy') return '$hero-ի պատմությունը';
    return 'A story about $hero';
  }

  String _summaryFor({
    required String lang,
    required String hero,
    required String companion,
    required String location,
    required String style,
    required String idea,
  }) {
    final base = _summaryBase(
      lang: lang,
      hero: hero,
      companion: companion,
      location: location,
      style: style,
    );
    if (idea.isEmpty) return base;
    if (lang == 'ru') return '$base Идея: $idea.';
    if (lang == 'hy') return '$base Գաղափար՝ $idea։';
    return '$base Idea: $idea.';
  }

  String _summaryBase({
    required String lang,
    required String hero,
    required String companion,
    required String location,
    required String style,
  }) {
    if (lang == 'ru') {
      return '$hero и $companion отправляются в $location, чтобы испытать "$style".';
    }
    if (lang == 'hy') {
      return '$hero և $companion գնում են $location՝ "$style" պատմության համար։';
    }
    return '$hero and $companion go to $location for a "$style" adventure.';
  }

  List<String> _choiceLabels({
    required String lang,
    required String location,
    required String style,
    required String companion,
  }) {
    if (lang == 'ru') {
      return <String>[
        'Пойти в $location',
        'Следовать за подсказкой',
        'Спросить совет у $companion',
      ];
    }
    if (lang == 'hy') {
      return <String>[
        'Գնալ $location',
        'Հետևել հուշմանը',
        'Հարցնել $companion-ին',
      ];
    }
    return <String>[
      'Go to $location',
      'Follow the hint',
      'Ask $companion for advice',
    ];
  }

  _Cast _buildCast({
    required String storyLang,
    required String hero,
    required FamilyProfile? family,
  }) {
    if (family != null && family.enabled) {
      final familyNames = _familyNamesWithFallback(storyLang, family);
      if (familyNames.isNotEmpty) {
        final main = familyNames.first;
        final companion = familyNames.length > 1
            ? familyNames[1]
            : _fallbackCompanion(storyLang);
        return _Cast(mainHero: main, companion: companion);
      }
    }

    final safeHero = hero.isNotEmpty ? hero : _fallbackHero(storyLang);
    return _Cast(mainHero: safeHero, companion: _fallbackCompanion(storyLang));
  }

  String _fallbackHero(String lang) {
    if (lang == 'ru') return 'Герой';
    if (lang == 'hy') return 'Հերոս';
    return 'Hero';
  }

  String _fallbackCompanion(String lang) {
    if (lang == 'ru') return 'друг';
    if (lang == 'hy') return 'ընկեր';
    return 'a friend';
  }

  String _defaultLocation(String lang) {
    if (lang == 'ru') return 'сказочное королевство';
    if (lang == 'hy') return 'հեքիաթային թագավորություն';
    return 'a fairytale kingdom';
  }

  String _defaultStyle(String lang) {
    if (lang == 'ru') return 'добрая';
    if (lang == 'hy') return 'բարի';
    return 'kind';
  }

  FamilyProfile? _familyFromBody(Map<String, dynamic> body) {
    final raw = body['family'];
    final enabled = (body['familyEnabled'] ?? false) as bool;
    if (raw is Map) {
      final data = Map<String, dynamic>.from(raw);
      data['enabled'] = data['enabled'] ?? enabled;
      return FamilyProfile.fromJson(data);
    }
    if (!enabled) return null;
    return FamilyProfile(
      enabled: true,
      grandfatherName: null,
      grandmotherName: null,
      fatherName: null,
      motherName: null,
      brothers: const <String>[],
      sisters: const <String>[],
    );
  }

  List<String> _familyNames(FamilyProfile family) {
    final names = <String>[];
    void add(String? v) {
      final t = v?.trim() ?? '';
      if (t.isNotEmpty) names.add(t);
    }

    add(family.grandfatherName);
    add(family.grandmotherName);
    add(family.fatherName);
    add(family.motherName);
    names.addAll(family.brothers.where((e) => e.trim().isNotEmpty));
    names.addAll(family.sisters.where((e) => e.trim().isNotEmpty));
    return names;
  }

  List<String> _familyNamesWithFallback(String lang, FamilyProfile family) {
    final names = _familyNames(family);
    if (names.isNotEmpty) return names;

    if (lang == 'ru') return const <String>['мама', 'папа'];
    if (lang == 'hy') return const <String>['մայրիկ', 'հայրիկ'];
    return const <String>['mom', 'dad'];
  }
}

class _Cast {
  final String mainHero;
  final String companion;

  const _Cast({required this.mainHero, required this.companion});
}

class _MockStoryPlan {
  final String storyId;
  final String title;
  final String summary;
  final int totalChapters;
  final String storyLang;
  final String hero;
  final String companion;
  final String location;
  final String style;
  final FamilyProfile? family;
  final List<int> choiceChapters;
  final List<String> pickedChoices;

  _MockStoryPlan({
    required this.storyId,
    required this.title,
    required this.summary,
    required this.totalChapters,
    required this.storyLang,
    required this.hero,
    required this.companion,
    required this.location,
    required this.style,
    required this.family,
    required this.choiceChapters,
    required this.pickedChoices,
  });
}
