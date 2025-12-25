import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/ui/ui_constants.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F0E6);
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NeumorphicCircleButton(
                icon: Icons.add,
                label: t.createStory,
                onTap: () => context.go('/setup'),
              ),
              const SizedBox(height: 28),
              _NeumorphicCircleButton(
                icon: Icons.menu_book_outlined,
                label: t.myStories,
                onTap: () => context.go('/reader'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeumorphicCircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NeumorphicCircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const bg = Color(0xFFF6F0E6);
    const shadowDark = Color(0xFFD8CFC2);
    const shadowLight = Color(0xFFFFFFFF);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: kHomeCircleDiameter,
        height: kHomeCircleDiameter,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: shadowLight,
              offset: Offset(-10, -10),
              blurRadius: 18,
            ),
            BoxShadow(
              color: shadowDark,
              offset: Offset(10, 10),
              blurRadius: 18,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: Colors.black54),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: kHomeCircleLabelMaxLines,
                overflow: TextOverflow.ellipsis,
                style: (theme.textTheme.titleLarge ?? const TextStyle())
                    .copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
