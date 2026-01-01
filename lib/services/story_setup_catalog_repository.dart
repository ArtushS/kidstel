import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../shared/models/catalog_item.dart';
import '../shared/models/story_setup_catalog_item.dart';
import 'icon_url_resolver.dart';

class StorySetupCatalogRepository {
  final FirebaseFirestore _db;

  StorySetupCatalogRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String name) {
    return _db.collection('catalog').doc('story_setup').collection(name);
  }

  CollectionReference<Map<String, dynamic>> _legacyV1Col(String name) {
    return _db.collection('story_setup').doc('v1').collection(name);
  }

  CollectionReference<Map<String, dynamic>> _topLevelCol(String name) {
    return _db.collection(name);
  }

  String _pickDisplayName(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required Locale locale,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};

    // Newer/simple schema.
    final directName = (data['name'] ?? '').toString().trim();
    if (directName.isNotEmpty) return directName;

    // Older/localized schema.
    final item = CatalogItem.fromDoc(doc);
    final localized = item.titleForLocale(locale).trim();
    if (localized.isNotEmpty) return localized;

    return '';
  }

  String _pickIconRef(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    // Newer schema: iconUrl may be https:// or gs:// (we resolve either way).
    final iconUrl = (data['iconUrl'] ?? data['icon_url'] ?? '')
        .toString()
        .trim();
    if (iconUrl.isNotEmpty) return iconUrl;

    // Older schema: iconPath (prefer gs://), or a storage path.
    final item = CatalogItem.fromDoc(doc);
    return item.iconPath.trim();
  }

  num _pickOrder(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawOrder = data['order'];
    if (rawOrder is num) return rawOrder;
    return num.tryParse((rawOrder ?? '').toString()) ?? 9999;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getSnapshot(
    CollectionReference<Map<String, dynamic>> col, {
    required String label,
  }) async {
    // Prefer server-side ordering, but don't fail the whole catalog if the
    // field is missing or an index isn't available yet.
    try {
      return await col.orderBy('order').get();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[StorySetupCatalogRepository] $label: orderBy(order) failed: $e; falling back to unsorted get()',
        );
      }
      return await col.get();
    }
  }

  Future<List<StorySetupCatalogItem>> _loadFrom(
    CollectionReference<Map<String, dynamic>> col, {
    required String name,
    required String sourceLabel,
    required Locale locale,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[StorySetupCatalogRepository] load "$name" source=$sourceLabel locale=${locale.toLanguageTag()}',
      );
    }

    final snap = await _getSnapshot(
      col,
      label: 'source=$sourceLabel name=$name',
    );

    if (kDebugMode) {
      debugPrint(
        '[StorySetupCatalogRepository] raw snapshot "$name" source=$sourceLabel: docs=${snap.docs.length}',
      );
      for (final d in snap.docs.take(3)) {
        final data = d.data();
        final keys = data.keys.toList(growable: false);
        final previewName = (data['name'] ?? '').toString().trim();
        final previewIconUrl = (data['iconUrl'] ?? data['icon_url'] ?? '')
            .toString()
            .trim();
        final previewIconPath = (data['iconPath'] ?? data['icon_path'] ?? '')
            .toString()
            .trim();
        debugPrint(
          '[StorySetupCatalogRepository] sample "$name/${d.id}" source=$sourceLabel: keys=$keys name="$previewName" iconUrl="$previewIconUrl" iconPath="$previewIconPath"',
        );
      }
    }

    final items = <StorySetupCatalogItem>[];
    var skippedMissingTitle = 0;
    var skippedMissingIcon = 0;

    for (final doc in snap.docs) {
      final displayName = _pickDisplayName(doc, locale: locale);
      if (displayName.isEmpty) {
        skippedMissingTitle++;
        if (kDebugMode) {
          debugPrint(
            '[StorySetupCatalogRepository] skip "$name/${doc.id}" source=$sourceLabel: missing title/name',
          );
        }
        continue;
      }

      final iconRef = _pickIconRef(doc);
      if (iconRef.isEmpty) {
        skippedMissingIcon++;
        if (kDebugMode) {
          debugPrint(
            '[StorySetupCatalogRepository] skip "$name/${doc.id}" source=$sourceLabel: missing iconUrl/iconPath',
          );
        }
        continue;
      }

      final https = await IconUrlResolver.resolveToHttps(iconRef);
      final iconForUi = (https == null || https.isEmpty) ? iconRef : https;

      items.add(
        StorySetupCatalogItem(
          id: doc.id,
          name: displayName,
          iconUrl: iconForUi,
          order: _pickOrder(doc),
        ),
      );
    }

    items.sort((a, b) {
      final c = a.order.compareTo(b.order);
      if (c != 0) return c;
      return a.name.compareTo(b.name);
    });

    if (kDebugMode) {
      debugPrint(
        '[StorySetupCatalogRepository] result "$name" source=$sourceLabel: items=${items.length} skippedTitle=$skippedMissingTitle skippedIcon=$skippedMissingIcon',
      );
    }

    return items;
  }

  Future<List<StorySetupCatalogItem>> load(
    String name, {
    required Locale locale,
  }) async {
    // 1) Canonical: catalog/story_setup/<name>
    final canonical = await _loadFrom(
      _col(name),
      name: name,
      sourceLabel: 'catalog/story_setup',
      locale: locale,
    );
    if (canonical.isNotEmpty) return canonical;

    // 2) Legacy: story_setup/v1/<name>
    final legacy = await _loadFrom(
      _legacyV1Col(name),
      name: name,
      sourceLabel: 'story_setup/v1',
      locale: locale,
    );
    if (legacy.isNotEmpty) return legacy;

    // 3) Legacy: top-level collection (heroes/locations/types)
    final top = await _loadFrom(
      _topLevelCol(name),
      name: name,
      sourceLabel: 'top-level',
      locale: locale,
    );
    return top;
  }

  Future<List<StorySetupCatalogItem>> loadHeroes({required Locale locale}) =>
      load('heroes', locale: locale);
  Future<List<StorySetupCatalogItem>> loadLocations({required Locale locale}) =>
      load('locations', locale: locale);
  Future<List<StorySetupCatalogItem>> loadTypes({required Locale locale}) =>
      load('types', locale: locale);
}
