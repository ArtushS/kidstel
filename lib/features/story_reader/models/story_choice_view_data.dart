class StoryChoiceViewData {
  final String id;
  final String label;

  /// Payload that will be sent to Cloud Function (later)
  final Map<String, dynamic> payload;

  const StoryChoiceViewData({
    required this.id,
    required this.label,
    required this.payload,
  });
}
