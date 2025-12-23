import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing,
      onTap: onTap,
      dense: false,
    );
  }
}
