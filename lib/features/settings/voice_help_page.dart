import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/voice/open_system_settings.dart';
import '../../shared/voice/voice_input_controller.dart';

class VoiceHelpPage extends StatelessWidget {
  const VoiceHelpPage({super.key});

  Future<void> _openSettings(BuildContext context) async {
    final ok = await openAppSettings();
    if (!context.mounted) return;

    if (!ok) {
      final t = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.openSettingsManually)));
    }
  }

  Future<void> _tryAgain(BuildContext context) async {
    final voice = context.read<VoiceInputController>();
    await voice.init();

    if (kDebugMode) {
      debugPrint(
        'VoiceHelpPage: tryAgain -> locales=${voice.localeIds.length}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final voice = context.watch<VoiceInputController>();

    final supported = voice.hasArmenianSupport;
    final supportedLabel = supported
        ? t.voiceHelpSupportedYes
        : t.voiceHelpSupportedNo;

    return Scaffold(
      appBar: AppBar(title: Text(t.voiceHelpTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t.voiceHelpArmenianTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${t.voiceHelpStatusLabel}: $supportedLabel',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  supported ? Icons.check_circle : Icons.error_outline,
                  color: supported ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(supported ? t.voiceHelpSupportedHint : t.voiceHelpSteps),
            const SizedBox(height: 18),

            // Optional diagnostics in debug mode
            if (kDebugMode) ...[
              const Divider(height: 28),
              Text('Debug', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                'isAvailable=${voice.isAvailable}  isListening=${voice.isListening}\n'
                'locales=${voice.localeIds.take(10).join(', ')}\n'
                'lastResolved=${voice.lastResolvedLocaleId} current=${voice.currentLocaleId}\n'
                'error=${voice.error}',
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _openSettings(context),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(t.openSettings),
                ),
                OutlinedButton.icon(
                  onPressed: () => _tryAgain(context),
                  icon: const Icon(Icons.refresh),
                  label: Text(t.tryAgain),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(t.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
