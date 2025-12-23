import 'package:flutter/material.dart';
import 'settings_tile.dart';

class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.valueLabel,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final String valueLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(valueLabel),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
