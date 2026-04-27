import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/comic_models.dart';
import 'comic_document_factory.dart';

/// Extracts raw image bytes for a specific page from various comic sources.
class ComicPageExtractor {
  ComicPageExtractor._();

  /// Get image bytes for [pageIndex] (0-based) of [chapter].
  static Future<Uint8List?> getPageBytes(ComicChapter chapter, int pageIndex) async {
    final appDir = await getApplicationDocumentsDirectory();
    final importRoot = p.join(appDir.path, 'ReadItAll', 'Imports');
    final absolutePath = p.join(importRoot, chapter.sourceRelativePath);

    switch (chapter.format) {
      case ComicFormat.cbz:
      case ComicFormat.zip:
        return _getZipPageBytes(absolutePath, pageIndex);
      case ComicFormat.cbr:
      case ComicFormat.rar:
        return null; // TODO: RAR support
      case ComicFormat.pdf:
        return null; // Handled separately by pdf_render
      case ComicFormat.folder:
        return _getFolderPageBytes(absolutePath, pageIndex);
      case ComicFormat.image:
        final file = File(absolutePath);
        if (await file.exists()) return file.readAsBytes();
        return null;
    }
  }

  /// Get the file path for a page (for formats that support direct file access).
  static Future<String?> getPageFilePath(ComicChapter chapter, int pageIndex) async {
    final appDir = await getApplicationDocumentsDirectory();
    final importRoot = p.join(appDir.path, 'ReadItAll', 'Imports');
    final absolutePath = p.join(importRoot, chapter.sourceRelativePath);

    switch (chapter.format) {
      case ComicFormat.folder:
        final paths = await ComicDocumentFactory.extractImagePaths(absolutePath, chapter.format);
        if (pageIndex >= 0 && pageIndex < paths.length) return paths[pageIndex];
        return null;
      case ComicFormat.image:
        return absolutePath;
      default:
        return null;
    }
  }

  static Future<Uint8List?> _getZipPageBytes(String zipPath, int pageIndex) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final imageFiles = archive.files
          .where((f) => f.isFile && ComicDocumentFactory.isImagePath(f.name))
          .toList();
      imageFiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (pageIndex < 0 || pageIndex >= imageFiles.length) return null;
      return Uint8List.fromList(imageFiles[pageIndex].content);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _getFolderPageBytes(String folderPath, int pageIndex) async {
    try {
      final paths = await ComicDocumentFactory.extractImagePaths(folderPath, ComicFormat.folder);
      if (pageIndex < 0 || pageIndex >= paths.length) return null;
      return File(paths[pageIndex]).readAsBytes();
    } catch (_) {
      return null;
    }
  }
}

