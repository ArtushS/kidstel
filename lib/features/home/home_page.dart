import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F0E6);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NeumorphicCircleButton(
                icon: Icons.add,
                label: 'Create Story',
                onTap: () => context.go('/setup'),
              ),
              const SizedBox(height: 28),
              _NeumorphicCircleButton(
                icon: Icons.menu_book_outlined,
                label: 'My Stories',
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
    const bg = Color(0xFFF6F0E6);
    const shadowDark = Color(0xFFD8CFC2);
    const shadowLight = Color(0xFFFFFFFF);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        height: 220,
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
            Text(
              label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
