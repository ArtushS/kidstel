import 'package:flutter/foundation.dart';

/// Shared, data-only representation of remotely managed app policy.
///
/// This is intended as the contract between a future admin panel and the
/// mobile app.
///
/// IMPORTANT:
/// - Do not put service logic here.
/// - Keep it JSON/Firestore friendly.
/// - Backward compatible: new fields must be optional.
@immutable
class AdminPolicyConfig {
  /// Global kill-switch.
  final bool enabled;

  /// Whether automatic illustrations are allowed.
  final bool allowAutoIllustrations;

  /// Optional allow-list of story languages (BCP-47 / language codes).
  /// Empty/null means "no restriction".
  final List<String>? allowedLanguageCodes;

  /// Optional maximum story length token/step hint.
  /// (Exact semantics can be defined later; keep nullable for compatibility.)
  final int? maxStoryLengthHint;

  const AdminPolicyConfig({
    required this.enabled,
    required this.allowAutoIllustrations,
    required this.allowedLanguageCodes,
    required this.maxStoryLengthHint,
  });

  factory AdminPolicyConfig.defaults() => const AdminPolicyConfig(
    enabled: true,
    allowAutoIllustrations: true,
    allowedLanguageCodes: null,
    maxStoryLengthHint: null,
  );

  factory AdminPolicyConfig.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final allowAutoIllustrations =
        json['allowAutoIllustrations'] ?? json['allow_auto_illustrations'];

    final langs =
        json['allowedLanguageCodes'] ??
        json['allowed_language_codes'] ??
        json['allowedLanguages'] ??
        json['allowed_languages'];

    List<String>? allowed;
    if (langs is List) {
      allowed = langs
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }

    final maxHint = json['maxStoryLengthHint'] ?? json['max_story_length_hint'];

    return AdminPolicyConfig(
      enabled: (enabled is bool) ? enabled : true,
      allowAutoIllustrations: (allowAutoIllustrations is bool)
          ? allowAutoIllustrations
          : true,
      allowedLanguageCodes: allowed,
      maxStoryLengthHint: (maxHint is int)
          ? maxHint
          : int.tryParse((maxHint ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    'allowAutoIllustrations': allowAutoIllustrations,
    if (allowedLanguageCodes != null)
      'allowedLanguageCodes': allowedLanguageCodes,
    if (maxStoryLengthHint != null) 'maxStoryLengthHint': maxStoryLengthHint,
  };

  AdminPolicyConfig copyWith({
    bool? enabled,
    bool? allowAutoIllustrations,
    List<String>? allowedLanguageCodes,
    int? maxStoryLengthHint,
  }) {
    return AdminPolicyConfig(
      enabled: enabled ?? this.enabled,
      allowAutoIllustrations:
          allowAutoIllustrations ?? this.allowAutoIllustrations,
      allowedLanguageCodes: allowedLanguageCodes ?? this.allowedLanguageCodes,
      maxStoryLengthHint: maxStoryLengthHint ?? this.maxStoryLengthHint,
    );
  }
}
