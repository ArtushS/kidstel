import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../l10n/app_localizations.dart';

/// Displays a story chapter image in a safe, kid-friendly way.
///
/// Priority:
/// 1) [imageUrl] (http/https) -> network image
/// 2) [imageBase64] -> decoded bytes -> memory image
/// 3) placeholder card
///
/// Notes:
/// - Never throws on invalid/empty inputs.
/// - Never logs tokens or story content.
class StoryImageSection extends StatefulWidget {
  final String? imageUrl;
  final String? imageBase64;

  /// When true, the section is still shown even if there is no image
  /// (a placeholder card is displayed).
  final bool showPlaceholderWhenEmpty;

  /// Default aspect ratio is 1:1 (matches carousel card feel).
  final double aspectRatio;

  const StoryImageSection({
    super.key,
    required this.imageUrl,
    required this.imageBase64,
    this.showPlaceholderWhenEmpty = true,
    this.aspectRatio = 1.0,
  });

  @override
  State<StoryImageSection> createState() => _StoryImageSectionState();
}

class _StoryImageSectionState extends State<StoryImageSection> {
  Future<String?>? _resolvedUrlFuture;
  String? _resolvedKey;

  @override
  void initState() {
    super.initState();
    _syncResolver();
  }

  @override
  void didUpdateWidget(covariant StoryImageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _syncResolver();
    }
  }

  void _syncResolver() {
    final raw = (widget.imageUrl ?? '').trim();
    final key = raw;
    if (_resolvedKey == key) return;
    _resolvedKey = key;

    final kind = _classifyUrl(raw);
    switch (kind) {
      case _UrlKind.http:
      case _UrlKind.none:
      case _UrlKind.unsupported:
        _resolvedUrlFuture = null;
        break;
      case _UrlKind.storageRefFromUrl:
      case _UrlKind.storagePath:
        _resolvedUrlFuture = _resolveStorageToDownloadUrl(raw);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rawUrl = (widget.imageUrl ?? '').trim();
    final urlKind = _classifyUrl(rawUrl);

    final base64Payload = _stripDataUriPrefix(widget.imageBase64);
    final base64Len = base64Payload?.length ?? 0;
    final bytes = _decodeBase64(base64Payload);
    final bytesUsable = bytes != null && bytes.isNotEmpty && !_is1x1Png(bytes);

    _debugMeta(
      hasImageUrl: rawUrl.isNotEmpty,
      urlKind: urlKind,
      hasBase64: base64Len > 0,
      base64Len: base64Len,
    );

    final showPlaceholderWhenEmpty = widget.showPlaceholderWhenEmpty;

    if (!bytesUsable && rawUrl.isEmpty && !showPlaceholderWhenEmpty) {
      return const SizedBox.shrink();
    }

    Widget image;
    if (bytesUsable) {
      image = Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      );
    } else if (urlKind == _UrlKind.http) {
      image = Image.network(
        rawUrl,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      );
    } else if (_resolvedUrlFuture != null) {
      image = FutureBuilder<String?>(
        future: _resolvedUrlFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final url = (snap.data ?? '').trim();
          if (url.isEmpty || snap.hasError) {
            return _placeholder(context);
          }

          return Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) => _placeholder(context),
          );
        },
      );
    } else {
      image = _placeholder(context);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: image,
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final label = (l10n?.illustration ?? 'Illustration').trim();

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_outlined,
                size: 42,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _debugMeta({
    required bool hasImageUrl,
    required _UrlKind urlKind,
    required bool hasBase64,
    required int base64Len,
  }) {
    if (!kDebugMode) return;

    // IMPORTANT: do not print full URLs or any base64 payload.
    debugPrint(
      '[StoryImageSection] hasImageUrl=$hasImageUrl urlKind=${urlKind.name} hasBase64=$hasBase64 base64Len=$base64Len',
    );
  }

  static _UrlKind _classifyUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return _UrlKind.none;
    final lower = s.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return _UrlKind.http;
    }
    if (lower.startsWith('gs://') || lower.startsWith('storage://')) {
      return _UrlKind.storageRefFromUrl;
    }

    // If there's some other scheme, don't attempt to resolve.
    if (lower.contains('://')) {
      return _UrlKind.unsupported;
    }

    // No scheme: treat as Firebase Storage path in default bucket.
    return _UrlKind.storagePath;
  }

  Future<String?> _resolveStorageToDownloadUrl(String raw) async {
    final s = raw.trim();
    if (s.isEmpty) return null;

    try {
      final lower = s.toLowerCase();

      if (lower.startsWith('gs://')) {
        return await FirebaseStorage.instance.refFromURL(s).getDownloadURL();
      }

      if (lower.startsWith('storage://')) {
        // Best-effort: some backends use storage://bucket/path; Firebase expects gs://.
        final converted = 'gs://${s.substring('storage://'.length)}';
        return await FirebaseStorage.instance
            .refFromURL(converted)
            .getDownloadURL();
      }

      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        // Already a web URL.
        return s;
      }

      if (lower.contains('://')) {
        // Unknown scheme.
        return null;
      }

      // Path in default bucket.
      return await FirebaseStorage.instance.ref(s).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  static String? _stripDataUriPrefix(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;

    // Accept both raw base64 and data URIs.
    if (!s.startsWith('data:', 0)) return s;

    final comma = s.indexOf(',');
    if (comma < 0) return null;
    final payload = s.substring(comma + 1).trim();
    return payload.isEmpty ? null : payload;
  }

  static Uint8List? _decodeBase64(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    try {
      // Remove whitespace/newlines just in case.
      final compact = s.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(compact);
    } catch (_) {
      return null;
    }
  }

  /// Detects common server placeholders that are a valid but useless 1x1 PNG.
  ///
  /// Safe: only returns true for valid PNGs whose IHDR declares 1x1.
  static bool _is1x1Png(Uint8List bytes) {
    // PNG signature (8 bytes)
    const sig = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 24) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[i] != sig[i]) return false;
    }

    // First chunk should be IHDR: length(4) + type(4) at offset 8
    final type0 = bytes[12];
    final type1 = bytes[13];
    final type2 = bytes[14];
    final type3 = bytes[15];
    if (type0 != 73 || type1 != 72 || type2 != 68 || type3 != 82) {
      return false;
    }

    // Width/height big-endian at offset 16/20
    int be32(int o) =>
        (bytes[o] << 24) |
        (bytes[o + 1] << 16) |
        (bytes[o + 2] << 8) |
        (bytes[o + 3]);

    final w = be32(16);
    final h = be32(20);
    return w == 1 && h == 1;
  }
}

enum _UrlKind { none, http, storageRefFromUrl, storagePath, unsupported }
