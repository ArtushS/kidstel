import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/theme_controller.dart';
import '../../shared/theme/theme_scope.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeController _themeController(BuildContext context) =>
      ThemeScope.of(context);

  // App-like settings (MVP локально; позже можно сохранить в Firestore/SharedPreferences)
  bool _soundEffects = true;
  bool _music = false;
  bool _haptics = true;

  bool _autoPlayChapters = true;
  bool _showSubtitles = true;

  bool _voiceNarration = true;
  double _speechRate = 1.0; // 0.7..1.3
  String _voiceType = 'Warm'; // Warm / Neutral / Bright

  bool _kidMode = true;
  bool _requirePinForAdult = true;
  bool _filterScary = true;
  bool _filterViolence = true;

  bool _notifications = false;
  bool _dailyReminder = false;

  String _language = 'English'; // English / Russian / Armenian (MVP)

  bool _analytics = false;
  bool _crashReports = true;

  @override
  Widget build(BuildContext context) {
    final c = _themeController(context);

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: _handleBack,
              tooltip: 'Back',
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              // APPEARANCE
              _SectionHeader(title: 'Appearance'),
              _Card(
                child: Column(
                  children: [
                    _ThemeRadioTile(
                      title: 'System',
                      subtitle: 'Use device setting',
                      value: ThemeMode.system,
                      groupValue: c.mode,
                      onChanged: (v) => c.setMode(v),
                      icon: Icons.brightness_auto_rounded,
                    ),
                    const Divider(height: 1),
                    _ThemeRadioTile(
                      title: 'Light',
                      subtitle: 'Always light theme',
                      value: ThemeMode.light,
                      groupValue: c.mode,
                      onChanged: (v) => c.setMode(v),
                      icon: Icons.light_mode_rounded,
                    ),
                    const Divider(height: 1),
                    _ThemeRadioTile(
                      title: 'Dark',
                      subtitle: 'Always dark theme',
                      value: ThemeMode.dark,
                      groupValue: c.mode,
                      onChanged: (v) => c.setMode(v),
                      icon: Icons.dark_mode_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // LANGUAGE
              _SectionHeader(title: 'Language'),
              _Card(
                child: _DropdownTile<String>(
                  icon: Icons.language_rounded,
                  title: 'App language',
                  subtitle: 'UI language (MVP)',
                  value: _language,
                  items: const ['English', 'Russian', 'Armenian'],
                  onChanged: (v) => setState(() => _language = v),
                ),
              ),

              const SizedBox(height: 14),

              // STORY EXPERIENCE
              _SectionHeader(title: 'Story experience'),
              _Card(
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Auto-play chapters',
                      subtitle: 'Continue reading automatically',
                      value: _autoPlayChapters,
                      onChanged: (v) => setState(() => _autoPlayChapters = v),
                    ),
                    const Divider(height: 1),
                    _SwitchTile(
                      icon: Icons.subtitles_outlined,
                      title: 'Subtitles',
                      subtitle: 'Show text while narration plays',
                      value: _showSubtitles,
                      onChanged: (v) => setState(() => _showSubtitles = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // VOICE / NARRATION
              _SectionHeader(title: 'Voice & narration'),
              _Card(
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.record_voice_over_outlined,
                      title: 'Voice narration',
                      subtitle: 'Enable/disable narration globally',
                      value: _voiceNarration,
                      onChanged: (v) => setState(() => _voiceNarration = v),
                    ),
                    const Divider(height: 1),
                    _DropdownTile<String>(
                      icon: Icons.mic_none_rounded,
                      title: 'Voice type',
                      subtitle: 'Narrator style preset (MVP)',
                      value: _voiceType,
                      items: const ['Warm', 'Neutral', 'Bright'],
                      onChanged: (v) => setState(() => _voiceType = v),
                      enabled: _voiceNarration,
                    ),
                    const Divider(height: 1),
                    _SliderTile(
                      icon: Icons.speed_rounded,
                      title: 'Speech rate',
                      subtitle: 'Slow ↔ Fast',
                      value: _speechRate,
                      min: 0.7,
                      max: 1.3,
                      divisions: 6,
                      enabled: _voiceNarration,
                      label: _speechRate.toStringAsFixed(2),
                      onChanged: (v) => setState(() => _speechRate = v),
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.headphones_rounded,
                      title: 'Test voice',
                      subtitle: 'Play a short sample (stub)',
                      onTap: () =>
                          _showStub('Voice sample will be added later.'),
                      enabled: _voiceNarration,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // SOUND
              _SectionHeader(title: 'Sound & feedback'),
              _Card(
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.surround_sound_outlined,
                      title: 'Sound effects',
                      subtitle: 'Button sounds and UI effects',
                      value: _soundEffects,
                      onChanged: (v) => setState(() => _soundEffects = v),
                    ),
                    const Divider(height: 1),
                    _SwitchTile(
                      icon: Icons.music_note_outlined,
                      title: 'Background music',
                      subtitle: 'Ambient music in stories',
                      value: _music,
                      onChanged: (v) => setState(() => _music = v),
                    ),
                    const Divider(height: 1),
                    _SwitchTile(
                      icon: Icons.vibration_rounded,
                      title: 'Haptics',
                      subtitle: 'Vibration feedback',
                      value: _haptics,
                      onChanged: (v) => setState(() => _haptics = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // PARENTAL / SAFETY
              _SectionHeader(title: 'Parental & safety'),
              _Card(
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.child_care_rounded,
                      title: 'Kid mode',
                      subtitle: 'Child-friendly defaults',
                      value: _kidMode,
                      onChanged: (v) => setState(() => _kidMode = v),
                    ),
                    const Divider(height: 1),
                    _SwitchTile(
                      icon: Icons.pin_rounded,
                      title: 'Require PIN for adult settings',
                      subtitle: 'Protection against accidental changes',
                      value: _requirePinForAdult,
                      onChanged: (v) => setState(() => _requirePinForAdult = v),
                      enabled: _kidMode,
                    ),
                    const Divider(height: 1),
                    _SwitchTile(
                      icon: Icons.visibility_off_outlined,
                      title: 'Filter scary content',
                      subtitle: 'Reduce scary scenes (MVP)',
                      value: _filterScary,
                      onChanged: (v) => setState(() => _filterScary = v),
                      enabled: _kidMode,
                    ),
                    const Divider(height: 1),
                    _SwitchTile(
                      icon: Icons.shield_outlined,
                      title: 'Filter violence',
                      subtitle: 'Reduce aggressive scenes (MVP)',
                      value: _filterViolence,
                      onChanged: (v) => setState(() => _filterViolence = v),
                      enabled: _kidMode,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // NOTIFICATIONS
              _SectionHeader(title: 'Notifications'),
              _Card(
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.notifications_outlined,
                      title: 'Enable notifications',
                      subtitle: 'Allow reminders and updates (stub)',
                      value: _notifications,
                      onChanged: (v) => setState(() => _notifications = v),
                    ),
                    const Divider(height: 1),
                    _SwitchTile(
                      icon: Icons.alarm_rounded,
                      title: 'Daily reading reminder',
                      subtitle: 'Once per day (stub)',
                      value: _dailyReminder,
                      onChanged: (v) => setState(() => _dailyReminder = v),
                      enabled: _notifications,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ACCOUNT
              _SectionHeader(title: 'Account'),
              _Card(
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Profile',
                      subtitle: 'Manage account (stub)',
                      onTap: () =>
                          _showStub('Profile page will be added later.'),
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.star_outline_rounded,
                      title: 'Subscription',
                      subtitle: 'Manage plan (stub)',
                      onTap: () =>
                          _showStub('Subscription flow will be added later.'),
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.restore_rounded,
                      title: 'Restore purchases',
                      subtitle: 'App Store / Google Play (stub)',
                      onTap: () =>
                          _showStub('Restore purchases will be added later.'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // PRIVACY & DATA
              _SectionHeader(title: 'Privacy & data'),
              _Card(
                child: Column(
                  children: [
                    _SwitchTile(
                      icon: Icons.analytics_outlined,
                      title: 'Analytics',
                      subtitle: 'Help improve the app (stub)',
                      value: _analytics,
                      onChanged: (v) => setState(() => _analytics = v),
                    ),
                    const Divider(height: 1),
                    _SwitchTile(
                      icon: Icons.bug_report_outlined,
                      title: 'Crash reports',
                      subtitle: 'Send anonymous crash logs (stub)',
                      value: _crashReports,
                      onChanged: (v) => setState(() => _crashReports = v),
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Clear cache',
                      subtitle: 'Remove downloaded images (stub)',
                      onTap: () =>
                          _showStub('Cache clearing will be added later.'),
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy policy',
                      subtitle: 'Open document (stub)',
                      onTap: () =>
                          _showStub('Privacy policy link will be added later.'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // SUPPORT / ABOUT
              _SectionHeader(title: 'Support & about'),
              _Card(
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help',
                      subtitle: 'FAQ & support (stub)',
                      onTap: () =>
                          _showStub('Help screen will be added later.'),
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'Contact support',
                      subtitle: 'Send feedback (stub)',
                      onTap: () =>
                          _showStub('Support contact will be added later.'),
                    ),
                    const Divider(height: 1),
                    _ActionTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'Version & credits (stub)',
                      onTap: () =>
                          _showStub('About screen will be added later.'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              FilledButton.icon(
                onPressed: () => _showStub('Sign-out will be added later.'),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out (stub)'),
              ),

              const SizedBox(height: 10),
              Text(
                'MVP: Settings are stored in memory for now. Next step: persist to Firebase/SharedPreferences.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleBack() {
    // Работает с GoRouter и с обычным Navigator
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/'); // fallback на Home
  }

  Future<void> _showStub(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('MVP'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/* ---------------- UI widgets ---------------- */

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );
  }
}

class _ThemeRadioTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final ThemeMode value;
  final ThemeMode groupValue;
  final IconData icon;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeRadioTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      title: Row(
        children: [Icon(icon), const SizedBox(width: 10), Text(title)],
      ),
      subtitle: Text(subtitle),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
      enabled: enabled,
      onTap: enabled ? () => onChanged(!value) : null,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      enabled: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}

class _DropdownTile<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  const _DropdownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<T>(
        value: value,
        onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
        items: items
            .map(
              (e) => DropdownMenuItem<T>(value: e, child: Text(e.toString())),
            )
            .toList(),
      ),
      enabled: enabled,
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final bool enabled;

  const _SliderTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 6),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
      enabled: enabled,
    );
  }
}
