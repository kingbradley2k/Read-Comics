import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/comic_models.dart';
import '../services/comic_page_extractor.dart';

/// Displays a thumbnail cover for a comic series or chapter.
class SeriesThumbnail extends StatelessWidget {
  final ComicChapter chapter;
  final double? width;
  final double? height;
  final BoxFit fit;

  const SeriesThumbnail({
    super.key,
    required this.chapter,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: ComicPageExtractor.getPageBytes(chapter, 0),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _placeholder(child: const CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          return Image.memory(
            snapshot.data!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _placeholder(),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder({Widget? child}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: child ?? const Icon(Icons.image, color: Colors.grey),
    );
  }
}

