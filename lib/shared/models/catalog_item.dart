import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// Generic catalog item used for story setup pickers (heroes/locations/styles/utils).
///
/// IMPORTANT: `iconPath` is a Firebase Storage reference (preferably a `gs://` URL)
/// and NOT a download URL.
class CatalogItem {
  final String id;
  final String titleEn;
  final String titleRu;
  final String titleHy;
  final String iconPath;

  const CatalogItem({
    required this.id,
    required this.titleEn,
    required this.titleRu,
    required this.titleHy,
    required this.iconPath,
  });

  String titleForLocale(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    switch (lang) {
      case 'ru':
        return titleRu.trim().isNotEmpty ? titleRu : titleEn;
      case 'hy':
        return titleHy.trim().isNotEmpty ? titleHy : titleEn;
      default:
        return titleEn;
    }
  }

  factory CatalogItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    String pickString(String key) => (data[key] ?? '').toString().trim();

    // Canonical fields.
    final titleEn = pickString('titleEn');
    final titleRu = pickString('titleRu');
    final titleHy = pickString('titleHy');

    // Accept common alternatives to be tolerant to older documents.
    final titleEnAlt = pickString('title_en');
    final titleRuAlt = pickString('title_ru');
    final titleHyAlt = pickString('title_hy');

    final iconPath = pickString('iconPath').isNotEmpty
        ? pickString('iconPath')
        : pickString('icon_path');

    return CatalogItem(
      id: doc.id,
      titleEn: titleEn.isNotEmpty ? titleEn : titleEnAlt,
      titleRu: titleRu.isNotEmpty ? titleRu : titleRuAlt,
      titleHy: titleHy.isNotEmpty ? titleHy : titleHyAlt,
      iconPath: iconPath,
    );
  }
}
