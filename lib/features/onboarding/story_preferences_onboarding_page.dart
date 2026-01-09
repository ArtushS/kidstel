import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/settings/app_settings.dart';
import '../../shared/settings/settings_scope.dart';
import '../story_preferences/widgets/story_preferences_fields.dart';

/// Пошаговый гайд по настройкам историй.
///
/// Важно:
/// - Показывается при первом запуске (onboardingCompleted=false) после логина.
/// - Работает с теми же настройками, что и статичная страница.
/// - Никакой реальной AI-генерации здесь нет; только UI и сохранение настроек.
class StoryPreferencesOnboardingPage extends StatefulWidget {
  const StoryPreferencesOnboardingPage({super.key});

  @override
  State<StoryPreferencesOnboardingPage> createState() =>
      _StoryPreferencesOnboardingPageState();
}

class _StoryPreferencesOnboardingPageState
    extends State<StoryPreferencesOnboardingPage> {
  late final PageController _pageCtrl;
  int _step = 0;

  static const int _stepsCount = 5;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _goTo(int next) async {
    if (next < 0 || next >= _stepsCount) return;
    setState(() => _step = next);
    await _pageCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() => _goTo(_step + 1);
  Future<void> _prev() => _goTo(_step - 1);

  Future<void> _skip(BuildContext context) async {
    final controller = SettingsScope.read(context);

    // Пользователь осознанно пропускает гайд.
    // Данные остаются дефолтными (мы ничего не сбрасываем/не меняем).
    await controller.setOnboardingCompleted(true);

    if (!context.mounted) return;
    context.go('/');
  }

  Future<void> _finish(BuildContext context) async {
    final controller = SettingsScope.read(context);
    await controller.setOnboardingCompleted(true);

    if (!context.mounted) return;
    context.go('/');
  }

  void _handleSystemBack(BuildContext context) {
    if (_step > 0) {
      _prev();
      return;
    }
    // На первом шаге не делаем "dead-end": выходим на Home.
    context.go('/');
  }

  Widget _dots(BuildContext context) {
    final theme = Theme.of(context);
    final active = theme.colorScheme.primary;
    final inactive = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _stepsCount; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _step ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _step ? active : inactive,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final controller = SettingsScope.of(context);

    if (!controller.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final s = controller.settings;

    final title = t.onboarding;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleSystemBack(context),
          ),
          actions: [
            TextButton(onPressed: () => _skip(context), child: Text(t.skip)),
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 8),
            _dots(context),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _StepScaffold(
                    title: t.hero,
                    subtitle: t.heroNameHelper,
                    child: PreferencesTextField(
                      leading: const Icon(Icons.person_outline),
                      label: t.heroNameLabel,
                      hint: t.heroNameHint,
                      helper: t.heroNameHelper,
                      value: s.heroName,
                      onChanged: controller.setHeroName,
                    ),
                  ),
                  _StepScaffold(
                    title: t.storyPreferences,
                    subtitle: t.beforeStoryGeneration,
                    child: StoryParamsEditor(
                      ageGroup: s.ageGroup,
                      onAgeGroupChanged: controller.setAgeGroup,
                      length: s.storyLength,
                      onLengthChanged: controller.setStoryLength,
                      complexity: s.storyComplexity,
                      onComplexityChanged: controller.setStoryComplexity,
                      interactiveEnabled: s.interactiveStoriesEnabled,
                      onInteractiveChanged:
                          controller.setInteractiveStoriesEnabled,
                    ),
                  ),
                  _StepScaffold(
                    title: t.family,
                    subtitle: t.familyEnabled,
                    child: FamilyEditor(
                      enabled: s.familyEnabled,
                      onEnabledChanged: controller.setFamilyEnabled,
                      grandfatherName: s.grandfatherName,
                      onGrandfatherChanged: controller.setGrandfatherName,
                      grandmotherName: s.grandmotherName,
                      onGrandmotherChanged: controller.setGrandmotherName,
                      fatherName: s.fatherName,
                      onFatherChanged: controller.setFatherName,
                      motherName: s.motherName,
                      onMotherChanged: controller.setMotherName,
                      brothers: s.brothers,
                      onBrothersChanged: controller.setBrothers,
                      sisters: s.sisters,
                      onSistersChanged: controller.setSisters,
                    ),
                  ),
                  _StepScaffold(
                    title: t.aiGeneration,
                    subtitle: t.autoGenerateIllustrations,
                    child: GenerationEditor(
                      autoIllustrations: s.autoIllustrations,
                      onAutoIllustrationsChanged:
                          controller.setAutoIllustrations,
                      creativity: s.creativityLevel,
                      onCreativityChanged: controller.setCreativityLevel,
                    ),
                  ),
                  _StepScaffold(
                    title: t.finish,
                    subtitle: t.storyGeneratedFromIdea,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.finish,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          // Короткое резюме, без перегруза.
                          '${t.hero}: ${s.heroName ?? '-'}\n'
                          '${t.ageGroup}: ${s.ageGroup.localized(context)}\n'
                          '${t.storyLength}: ${s.storyLength.localized(context)}\n'
                          '${t.complexity}: ${s.storyComplexity.localized(context)}',
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _finish(context),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(t.finish),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton.icon(
                        onPressed: _prev,
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          MaterialLocalizations.of(context).backButtonTooltip,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    if (_step < _stepsCount - 1)
                      FilledButton.icon(
                        onPressed: _next,
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(t.next),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: (theme.textTheme.headlineSmall ?? const TextStyle())
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
