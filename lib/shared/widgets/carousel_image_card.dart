import 'package:flutter/material.dart';

import 'network_icon.dart';

class CarouselImageCard extends StatelessWidget {
  const CarouselImageCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.height = 170,
    this.width = 140,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: height,
              width: width,
              child: NetworkIcon(
                imageUrl,
                width: width,
                height: height,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
