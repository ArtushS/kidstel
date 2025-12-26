import 'package:flutter/widgets.dart';
import 'settings_controller.dart';

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Returns the controller and *listens* for changes.
  ///
  /// Use this from `build()`/widgets that should rebuild when settings change.
  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in context');
    return scope!.notifier!;
  }

  /// Returns the controller *without* establishing a dependency.
  ///
  /// Safe for usage in Provider `create:` callbacks and `initState`.
  static SettingsController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<SettingsScope>();
    final widget = element?.widget as SettingsScope?;
    assert(widget != null, 'No SettingsScope found in context');
    return widget!.notifier!;
  }
}
