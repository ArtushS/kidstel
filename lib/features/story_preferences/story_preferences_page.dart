import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/settings/settings_scope.dart';
import 'widgets/story_preferences_fields.dart';

/// Постоянная страница "Параметры истории".
///
/// Это статичный хаб, доступный всегда с Home.
/// Здесь пользователь может осознанно управлять всеми параметрами,
/// которые также используются в онбординге.
class StoryPreferencesPage extends StatelessWidget {
  const StoryPreferencesPage({super.key});

  Future<void> _handleBack(BuildContext context) async {
    // IMPORTANT UX:
    // - This page can be opened from Create New Story.
    // - Back must return exactly to the previous screen (pop),
    //   without sending user to Home and without losing draft state.
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final controller = SettingsScope.of(context);

    if (!controller.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final s = controller.settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.storyPreferences),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBack(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          FilledButton.icon(
            onPressed: () {
              // Запускаем тот же гайд заново. Ничего не сбрасываем.
              context.push('/onboarding');
            },
            icon: const Icon(Icons.restart_alt_outlined),
            label: Text(t.restartGuide),
          ),
          const SizedBox(height: 16),
          Text(
            t.storyPreferences,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            // Короткое объяснение держим простым: важно для детей/родителей.
            t.beforeStoryGeneration,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),

          // 1) Герой
          PreferencesTextField(
            leading: const Icon(Icons.person_outline),
            label: t.heroNameLabel,
            hint: t.heroNameHint,
            helper: t.heroNameHelper,
            value: s.heroName,
            onChanged: controller.setHeroName,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),

          // 2) Параметры истории
          StoryParamsEditor(
            ageGroup: s.ageGroup,
            onAgeGroupChanged: controller.setAgeGroup,
            length: s.storyLength,
            onLengthChanged: controller.setStoryLength,
            complexity: s.storyComplexity,
            onComplexityChanged: controller.setStoryComplexity,
            interactiveEnabled: s.interactiveStoriesEnabled,
            onInteractiveChanged: controller.setInteractiveStoriesEnabled,
          ),
          const SizedBox(height: 18),

          // 3) Семья
          Text(
            t.family,
            style: (Theme.of(context).textTheme.titleLarge ?? const TextStyle())
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          FamilyEditor(
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
          const SizedBox(height: 18),

          // 4) Генерация (моковая; без реального AI)
          GenerationEditor(
            autoIllustrations: s.autoIllustrations,
            onAutoIllustrationsChanged: controller.setAutoIllustrations,
            creativity: s.creativityLevel,
            onCreativityChanged: controller.setCreativityLevel,
          ),
        ],
      ),
    );
  }
}
