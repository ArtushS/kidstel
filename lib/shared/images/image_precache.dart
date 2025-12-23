import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

Future<void> warmUpImageCache(BuildContext context, List<String> urls) async {
  for (final url in urls) {
    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
    } catch (_) {
      // игнорируем отдельные сбои
    }
  }
}
