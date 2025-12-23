import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.6),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(subtitle!, style: theme.textTheme.bodySmall),
            ),
          ],
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
