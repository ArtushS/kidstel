class StoryChoice {
  final String id;
  final String label;
  final Map<String, dynamic> payload;

  const StoryChoice({
    required this.id,
    required this.label,
    required this.payload,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'payload': payload,
  };

  factory StoryChoice.fromJson(Map<String, dynamic> json) {
    return StoryChoice(
      id: (json['id'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      payload: (json['payload'] is Map<String, dynamic>)
          ? (json['payload'] as Map<String, dynamic>)
          : <String, dynamic>{},
    );
  }
}
