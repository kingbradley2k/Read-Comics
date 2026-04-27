import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../models/comic_models.dart';

class ComicDocumentFactory {
  static final _imageExts = <String>{
    'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'gif', 'bmp', 'tif', 'tiff',
  };

  static bool isImagePath(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    return _imageExts.contains(ext);
  }

  static ComicFormat? detectFormat(String path) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    switch (ext) {
      case 'cbz':
      case 'zip':
        return ComicFormat.cbz;
      case 'cbr':
      case 'rar':
        return ComicFormat.cbr;
      case 'pdf':
        return ComicFormat.pdf;
      default:
        if (FileSystemEntity.isDirectorySync(path)) {
          return ComicFormat.folder;
        }
        if (isImagePath(path)) {
          return ComicFormat.image;
        }
        return null;
    }
  }

  static Future<int> inspectPageCount(String path, ComicFormat format) async {
    try {
      switch (format) {
        case ComicFormat.cbz:
        case ComicFormat.zip:
          return await _countZipImages(path);
        case ComicFormat.cbr:
        case ComicFormat.rar:
          return 0; // RAR extraction not yet implemented
        case ComicFormat.pdf:
          return 0; // PDF page count not yet implemented
        case ComicFormat.folder:
          return await _countFolderImages(path);
        case ComicFormat.image:
          return 1;
      }
    } catch (_) {
      return 0;
    }
  }

  static Future<List<String>> extractImagePaths(String path, ComicFormat format) async {
    switch (format) {
      case ComicFormat.cbz:
      case ComicFormat.zip:
        return await _extractZipImagePaths(path);
      case ComicFormat.cbr:
      case ComicFormat.rar:
        return []; // TODO: RAR support
      case ComicFormat.pdf:
        return []; // TODO: PDF support
      case ComicFormat.folder:
        return await _extractFolderImagePaths(path);
      case ComicFormat.image:
        return [path];
    }
  }

  static Future<int> _countZipImages(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    return archive.files
        .where((f) => f.isFile && isImagePath(f.name))
        .length;
  }

  static Future<int> _countFolderImages(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && isImagePath(entity.path)) count++;
    }
    return count;
  }

  static Future<List<String>> _extractZipImagePaths(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files
        .where((f) => f.isFile && isImagePath(f.name))
        .map((f) => f.name)
        .toList();
    names.sort(_naturalSort);
    return names;
  }

  static Future<List<String>> _extractFolderImagePaths(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final paths = <String>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && isImagePath(entity.path)) {
        paths.add(entity.path);
      }
    }
    paths.sort(_naturalSort);
    return paths;
  }

  static int _naturalSort(String a, String b) {
    return a.toLowerCase().compareTo(b.toLowerCase());
  }
}

