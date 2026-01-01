import 'package:cloud_firestore/cloud_firestore.dart';

/// A Story Setup catalog item stored in Firestore.
///
/// Source collections (read-only from client):
/// - catalog/story_setup/heroes
/// - catalog/story_setup/locations
/// - catalog/story_setup/types
///
/// Each document must contain:
/// - name (string)
/// - iconUrl (string)
///   - preferred: HTTPS download URL
///   - accepted (legacy): gs:// URL
///   - accepted (legacy): plain Storage path like "heroes_icons/bear.png"
/// - order (number)
class StorySetupCatalogItem {
  final String id;
  final String name;
  final String iconUrl;
  final num order;

  const StorySetupCatalogItem({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.order,
  });

  static StorySetupCatalogItem fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    final name = (data['name'] ?? '').toString().trim();
    final iconUrl = (data['iconUrl'] ?? '').toString().trim();

    final rawOrder = data['order'];
    final order = rawOrder is num
        ? rawOrder
        : num.tryParse((rawOrder ?? '').toString()) ?? 9999;

    return StorySetupCatalogItem(
      id: doc.id,
      name: name,
      iconUrl: iconUrl,
      order: order,
    );
  }
}
