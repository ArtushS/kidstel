import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/settings/app_settings.dart';

/// Небольшой debouncer для TextField, чтобы:
/// - настройки сохранялись "сразу",
/// - но при этом мы не дёргали репозиторий на каждый символ.
class _Debouncer {
  _Debouncer(this.delay);

  final Duration delay;
  Timer? _t;

  void run(VoidCallback fn) {
    _t?.cancel();
    _t = Timer(delay, fn);
  }

  void dispose() {
    _t?.cancel();
  }
}

class PreferencesTextField extends StatefulWidget {
  const PreferencesTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.helper,
    required this.value,
    required this.onChanged,
    this.leading,
    this.textInputAction,
  });

  final Widget? leading;
  final String label;
  final String hint;
  final String helper;
  final String? value;
  final ValueChanged<String?> onChanged;
  final TextInputAction? textInputAction;

  @override
  State<PreferencesTextField> createState() => _PreferencesTextFieldState();
}

class _PreferencesTextFieldState extends State<PreferencesTextField> {
  final _focus = FocusNode();
  late final TextEditingController _ctrl;
  late final _Debouncer _debouncer;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value ?? '');
    _debouncer = _Debouncer(const Duration(milliseconds: 250));
  }

  @override
  void didUpdateWidget(covariant PreferencesTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.value ?? '';
    // Не перетираем ввод, пока фокус в поле.
    if (!_focus.hasFocus && _ctrl.text != nextText) {
      _ctrl.text = nextText;
    }
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _emit(String raw) {
    final v = raw.trim();
    widget.onChanged(v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.leading != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: widget.leading!,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.helper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: widget.textInputAction,
                decoration: InputDecoration(
                  labelText: widget.label,
                  hintText: widget.hint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  // Сохраняем быстро, но без "спама".
                  _debouncer.run(() => _emit(v));
                },
                onSubmitted: (v) => _emit(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class EnumChoiceChips<T> extends StatelessWidget {
  const EnumChoiceChips({
    super.key,
    required this.title,
    required this.current,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final T current;
  final List<T> values;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(label(v), overflow: TextOverflow.ellipsis),
                selected: v == current,
                onSelected: (_) => onChanged(v),
              ),
          ],
        ),
      ],
    );
  }
}

class StringListEditor extends StatefulWidget {
  const StringListEditor({
    super.key,
    required this.title,
    required this.addLabel,
    required this.values,
    required this.onChanged,
  });

  final String title;
  final String addLabel;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<StringListEditor> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;

    final next = [
      ...widget.values,
      raw,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);

    widget.onChanged(next);
    _ctrl.clear();
  }

  void _removeAt(int i) {
    if (i < 0 || i >= widget.values.length) return;
    final next = [...widget.values]..removeAt(i);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: t.familyNameHint,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(widget.addLabel),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (widget.values.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < widget.values.length; i++)
                InputChip(
                  label: Text(widget.values[i]),
                  onDeleted: () => _removeAt(i),
                  deleteIcon: const Icon(Icons.close),
                ),
            ],
          ),
      ],
    );
  }
}

class FamilyEditor extends StatelessWidget {
  const FamilyEditor({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.grandfatherName,
    required this.onGrandfatherChanged,
    required this.grandmotherName,
    required this.onGrandmotherChanged,
    required this.fatherName,
    required this.onFatherChanged,
    required this.motherName,
    required this.onMotherChanged,
    required this.brothers,
    required this.onBrothersChanged,
    required this.sisters,
    required this.onSistersChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;

  final String? grandfatherName;
  final ValueChanged<String?> onGrandfatherChanged;

  final String? grandmotherName;
  final ValueChanged<String?> onGrandmotherChanged;

  final String? fatherName;
  final ValueChanged<String?> onFatherChanged;

  final String? motherName;
  final ValueChanged<String?> onMotherChanged;

  final List<String> brothers;
  final ValueChanged<List<String>> onBrothersChanged;

  final List<String> sisters;
  final ValueChanged<List<String>> onSistersChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.family_restroom_outlined),
          title: Text(t.familyEnabled),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        const SizedBox(height: 8),
        if (enabled) ...[
          PreferencesTextField(
            leading: const Icon(Icons.elderly_outlined),
            label: t.grandfather,
            hint: t.familyNameHint,
            helper: t.familyNameHelper,
            value: grandfatherName,
            onChanged: onGrandfatherChanged,
          ),
          const SizedBox(height: 12),
          PreferencesTextField(
            leading: const Icon(Icons.elderly_woman_outlined),
            label: t.grandmother,
            hint: t.familyNameHint,
            helper: t.familyNameHelper,
            value: grandmotherName,
            onChanged: onGrandmotherChanged,
          ),
          const SizedBox(height: 12),
          PreferencesTextField(
            leading: const Icon(Icons.man_outlined),
            label: t.father,
            hint: t.familyNameHint,
            helper: t.familyNameHelper,
            value: fatherName,
            onChanged: onFatherChanged,
          ),
          const SizedBox(height: 12),
          PreferencesTextField(
            leading: const Icon(Icons.woman_outlined),
            label: t.mother,
            hint: t.familyNameHint,
            helper: t.familyNameHelper,
            value: motherName,
            onChanged: onMotherChanged,
          ),
          const SizedBox(height: 14),
          StringListEditor(
            title: t.brothers,
            addLabel: t.addBrother,
            values: brothers,
            onChanged: onBrothersChanged,
          ),
          const SizedBox(height: 14),
          StringListEditor(
            title: t.sisters,
            addLabel: t.addSister,
            values: sisters,
            onChanged: onSistersChanged,
          ),
        ],
      ],
    );
  }
}

class StoryParamsEditor extends StatelessWidget {
  const StoryParamsEditor({
    super.key,
    required this.ageGroup,
    required this.onAgeGroupChanged,
    required this.length,
    required this.onLengthChanged,
    required this.complexity,
    required this.onComplexityChanged,
    required this.interactiveEnabled,
    required this.onInteractiveChanged,
  });

  final AgeGroup ageGroup;
  final ValueChanged<AgeGroup> onAgeGroupChanged;

  final StoryLength length;
  final ValueChanged<StoryLength> onLengthChanged;

  final StoryComplexity complexity;
  final ValueChanged<StoryComplexity> onComplexityChanged;

  final bool interactiveEnabled;
  final ValueChanged<bool> onInteractiveChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EnumChoiceChips<AgeGroup>(
          title: t.ageGroup,
          current: ageGroup,
          values: AgeGroup.values,
          label: (v) => v.localized(context),
          onChanged: onAgeGroupChanged,
        ),
        const SizedBox(height: 16),
        EnumChoiceChips<StoryLength>(
          title: t.storyLength,
          current: length,
          values: StoryLength.values,
          label: (v) => v.localized(context),
          onChanged: onLengthChanged,
        ),
        const SizedBox(height: 16),
        EnumChoiceChips<StoryComplexity>(
          title: t.complexity,
          current: complexity,
          values: StoryComplexity.values,
          label: (v) => v.localized(context),
          onChanged: onComplexityChanged,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.touch_app_outlined),
          title: Text(t.interactiveStories),
          subtitle: Text(
            t.interactiveStoriesSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          value: interactiveEnabled,
          onChanged: onInteractiveChanged,
        ),
      ],
    );
  }
}

class GenerationEditor extends StatelessWidget {
  const GenerationEditor({
    super.key,
    required this.autoIllustrations,
    required this.onAutoIllustrationsChanged,
    required this.creativity,
    required this.onCreativityChanged,
  });

  final bool autoIllustrations;
  final ValueChanged<bool> onAutoIllustrationsChanged;

  final CreativityLevel creativity;
  final ValueChanged<CreativityLevel> onCreativityChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.image_outlined),
          title: Text(t.autoGenerateIllustrations),
          value: autoIllustrations,
          onChanged: onAutoIllustrationsChanged,
        ),
        const SizedBox(height: 12),
        EnumChoiceChips<CreativityLevel>(
          title: t.creativityLevel,
          current: creativity,
          values: CreativityLevel.values,
          label: (v) => v.localized(context),
          onChanged: onCreativityChanged,
        ),
      ],
    );
  }
}
