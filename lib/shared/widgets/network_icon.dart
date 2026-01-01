import 'dart:math';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../storage_urls.dart';

/// A resilient icon widget that renders an image from the network.
///
/// Requirements:
/// - UI renders only https URLs (Firebase Storage downloadURL).
/// - If [url] is gs://, it will be resolved to https via Firebase Storage.
/// - While loading / on error / invalid url: always fall back to the
///   centralized Storage placeholder (from Firebase Storage).
/// - Never throws for empty/invalid URLs.
class NetworkIcon extends StatelessWidget {
  final String? url;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Color? backgroundColor;

  const NetworkIcon(
    this.url, {
    super.key,
    this.size = 128,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.backgroundColor,
  });

  static bool _isHttps(String s) => s.startsWith('https://');
  static bool _isGs(String s) => s.startsWith('gs://');

  static final Map<String, String> _gsToHttpsCache = <String, String>{};
  static final Map<String, String> _pathToHttpsCache = <String, String>{};

  Future<String?> _resolveToHttps(String raw) async {
    final v = raw.trim();
    if (v.isEmpty) return null;
    if (_isHttps(v)) return v;

    if (_isGs(v)) {
      final cached = _gsToHttpsCache[v];
      if (cached != null && cached.trim().isNotEmpty) return cached;

      try {
        final https = await FirebaseStorage.instance
            .refFromURL(v)
            .getDownloadURL();
        _gsToHttpsCache[v] = https;
        return https;
      } catch (_) {
        return null;
      }
    }

    // Treat everything else as a Storage path (defensive; some older docs store
    // icons as "heroes_icons/bear.png" instead of gs:// URLs).
    final cached = _pathToHttpsCache[v];
    if (cached != null && cached.trim().isNotEmpty) return cached;

    try {
      final https = await FirebaseStorage.instance.ref(v).getDownloadURL();
      _pathToHttpsCache[v] = https;
      return https;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    final w = width ?? size;
    final h = height ?? size;

    Widget fallback({IconData icon = Icons.image_outlined}) {
      return Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: borderRadius,
        ),
        child: Icon(
          icon,
          size: (min(w, h) * 0.45).clamp(18.0, 64.0),
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    Widget placeholderFromStorage() {
      return FutureBuilder<String>(
        future: StorageUrls.getPlaceholderDownloadUrl(),
        builder: (context, snap) {
          final p = (snap.data ?? '').trim();
          if (!_isHttps(p)) {
            return fallback(icon: Icons.image_outlined);
          }

          return ClipRRect(
            borderRadius: borderRadius,
            child: SizedBox(
              width: w,
              height: h,
              child: Image.network(
                p,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    fallback(icon: Icons.broken_image_outlined),
              ),
            ),
          );
        },
      );
    }

    return FutureBuilder<String?>(
      future: _resolveToHttps(u),
      builder: (context, snap) {
        final https = (snap.data ?? '').trim();
        if (!_isHttps(https)) {
          return placeholderFromStorage();
        }

        return ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
            width: w,
            height: h,
            child: Image.network(
              https,
              fit: fit,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return placeholderFromStorage();
              },
              errorBuilder: (context, error, stackTrace) =>
                  placeholderFromStorage(),
            ),
          ),
        );
      },
    );
  }
}
