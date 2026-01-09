class FamilyProfile {
  final bool enabled;
  final String? grandfatherName;
  final String? grandmotherName;
  final String? fatherName;
  final String? motherName;
  final List<String> brothers;
  final List<String> sisters;

  const FamilyProfile({
    required this.enabled,
    required this.grandfatherName,
    required this.grandmotherName,
    required this.fatherName,
    required this.motherName,
    required this.brothers,
    required this.sisters,
  });

  factory FamilyProfile.empty() => const FamilyProfile(
    enabled: false,
    grandfatherName: null,
    grandmotherName: null,
    fatherName: null,
    motherName: null,
    brothers: <String>[],
    sisters: <String>[],
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'grandfatherName': grandfatherName,
    'grandmotherName': grandmotherName,
    'fatherName': fatherName,
    'motherName': motherName,
    'brothers': brothers,
    'sisters': sisters,
  };

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    List<String> listFromJson(Object? raw) {
      if (raw is List) {
        return raw
            .map((e) => e?.toString() ?? '')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    return FamilyProfile(
      enabled: (json['enabled'] ?? false) as bool,
      grandfatherName: json['grandfatherName']?.toString(),
      grandmotherName: json['grandmotherName']?.toString(),
      fatherName: json['fatherName']?.toString(),
      motherName: json['motherName']?.toString(),
      brothers: listFromJson(json['brothers']),
      sisters: listFromJson(json['sisters']),
    );
  }
}
