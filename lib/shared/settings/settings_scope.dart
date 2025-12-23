import 'package:flutter/widgets.dart';
import 'settings_controller.dart';

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required Widget child,
  }) : super(notifier: controller, child: child);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope found in context');
    return scope!.notifier!;
  }
}
