import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/comic_models.dart';
import '../utils/comic_filename_parser.dart';
import 'comic_document_factory.dart';

class ComicLibraryService extends ChangeNotifier {
  List<ComicChapter> _chapters = [];
  final Map<String, ComicProgress> _progressById = {};
  String? _lastError;
  bool _isImporting = false;

  Box<ComicChapter>? _chapterBox;
  Box<ComicProgress>? _progressBox;

  List<ComicChapter> get chapters => _chapters;
  String? get lastError => _lastError;
  bool get isImporting => _isImporting;

  List<ComicSeries> get series {
    final grouped = <String, List<ComicChapter>>{};
    for (var chapter in _chapters) {
      grouped.putIfAbsent(chapter.seriesKey, () => []).add(chapter);
    }
    return grouped.entries
        .map((e) => ComicSeries(
              key: e.key,
              title: e.value.first.seriesTitle,
              chapters: _sortChapters(e.value),
            ))
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  Future<void> init() async {
    _chapterBox = Hive.box<ComicChapter>('chapters');
    _progressBox = Hive.box<ComicProgress>('progress');
    _loadFromHive();
  }

  void _loadFromHive() {
    if (_chapterBox == null) return;
    _chapters = _chapterBox!.values.toList();
    _progressById.clear();
    if (_progressBox != null) {
      for (final entry in _progressBox!.toMap().entries) {
        _progressById[entry.key] = entry.value;
      }
    }
    notifyListeners();
  }

  Future<void> pickAndImportFiles() async {
    _lastError = null;
    _isImporting = true;
    notifyListeners();

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['cbz', 'cbr', 'zip', 'rar', 'pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result == null || result.files.isEmpty) {
        _isImporting = false;
        notifyListeners();
        return;
      }

      for (final file in result.files) {
        if (file.path != null) {
          await _importFile(file.path!);
        }
      }
    } catch (e) {
      _lastError = 'Import failed: $e';
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> _importFile(String sourcePath) async {
    final format = ComicDocumentFactory.detectFormat(sourcePath);
    if (format == null) {
      _lastError = 'Unsupported format: $sourcePath';
      return;
    }

    final file = File(sourcePath);
    if (!await file.exists()) {
      _lastError = 'File not found: $sourcePath';
      return;
    }

    final parsed = ComicFilenameParser.parse(file);
    final appDir = await getApplicationDocumentsDirectory();
    final importRoot = Directory(p.join(appDir.path, 'ReadItAll', 'Imports'));
    await importRoot.create(recursive: true);

    final seriesDir = Directory(p.join(importRoot.path, parsed.seriesKey));
    await seriesDir.create(recursive: true);

    final destName = _sanitizeFilename(file.path.split(Platform.pathSeparator).last);
    final destPath = _uniquePath(seriesDir.path, destName, isDirectory: format == ComicFormat.folder);

    // Copy file or folder
    if (format == ComicFormat.folder) {
      await _copyDirectory(Directory(sourcePath), Directory(destPath));
    } else {
      await file.copy(destPath);
    }

    final relativePath = p.relative(destPath, from: importRoot.path);
    final pageCount = await ComicDocumentFactory.inspectPageCount(destPath, format);

    final chapter = ComicChapter(
      id: '${parsed.seriesKey}_${DateTime.now().millisecondsSinceEpoch}',
      seriesKey: parsed.seriesKey,
      seriesTitle: parsed.seriesTitle,
      chapterTitle: parsed.chapterTitle,
      originalFilename: file.path.split(Platform.pathSeparator).last,
      sourceRelativePath: relativePath,
      format: format,
      importedAt: DateTime.now(),
      modifiedAt: await file.lastModified(),
      issueNumber: parsed.issueNumber,
      pageCount: pageCount > 0 ? pageCount : null,
    );

    _chapters.add(chapter);
    _chapters = _sortChapters(_chapters);
    await _chapterBox?.put(chapter.id, chapter);
    notifyListeners();
  }

  Future<void> deleteChapter(ComicChapter chapter) async {
    _lastError = null;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final importRoot = Directory(p.join(appDir.path, 'ReadItAll', 'Imports'));
      final storagePath = p.join(importRoot.path, chapter.sourceRelativePath);
      final entity = FileSystemEntity.typeSync(storagePath);
      if (entity == FileSystemEntityType.file) {
        await File(storagePath).delete();
      } else if (entity == FileSystemEntityType.directory) {
        await Directory(storagePath).delete(recursive: true);
      }
      _chapters.removeWhere((c) => c.id == chapter.id);
      _progressById.remove(chapter.id);
      await _chapterBox?.delete(chapter.id);
      await _progressBox?.delete(chapter.id);
      notifyListeners();
    } catch (e) {
      _lastError = 'Delete failed: $e';
      notifyListeners();
    }
  }

  Future<void> deleteSeries(ComicSeries series) async {
    _lastError = null;
    try {
      for (final chapter in series.chapters) {
        await deleteChapter(chapter);
      }
      notifyListeners();
    } catch (e) {
      _lastError = 'Delete series failed: $e';
      notifyListeners();
    }
  }

  ComicProgress progressFor(String chapterId) {
    return _progressById[chapterId] ?? ComicProgress(lastReadAt: DateTime.now());
  }

  Future<void> updateProgress(String chapterId, int pageIndex) async {
    final progress = ComicProgress(
      pageIndex: pageIndex,
      lastReadAt: DateTime.now(),
    );
    _progressById[chapterId] = progress;
    await _progressBox?.put(chapterId, progress);
    notifyListeners();
  }

  ComicChapter? chapterById(String id) {
    try {
      return _chapters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  List<ComicChapter> chaptersInSeries(String seriesKey) {
    return _sortChapters(_chapters.where((c) => c.seriesKey == seriesKey).toList());
  }

  ComicChapter? resumeChapter(String seriesKey) {
    final seriesChapters = chaptersInSeries(seriesKey);
    if (seriesChapters.isEmpty) return null;
    ComicChapter? best;
    DateTime? bestDate;
    for (final chapter in seriesChapters) {
      final progress = _progressById[chapter.id];
      if (progress != null) {
        if (bestDate == null || progress.lastReadAt.isAfter(bestDate)) {
          best = chapter;
          bestDate = progress.lastReadAt;
        }
      }
    }
    return best ?? seriesChapters.first;
  }

  String storagePathFor(ComicChapter chapter) {
    // This would be resolved at runtime with path_provider
    return chapter.sourceRelativePath;
  }

  static List<ComicChapter> _sortChapters(List<ComicChapter> list) {
    return list..sort((a, b) {
      if (a.seriesTitle.toLowerCase() != b.seriesTitle.toLowerCase()) {
        return a.seriesTitle.toLowerCase().compareTo(b.seriesTitle.toLowerCase());
      }
      if (a.issueNumber != null && b.issueNumber != null && a.issueNumber != b.issueNumber) {
        return a.issueNumber!.compareTo(b.issueNumber!);
      }
      if (a.issueNumber != null && b.issueNumber == null) return -1;
      if (a.issueNumber == null && b.issueNumber != null) return 1;
      return a.chapterTitle.toLowerCase().compareTo(b.chapterTitle.toLowerCase());
    });
  }

  static String _sanitizeFilename(String name) {
    return name.replaceAll('/', '-').replaceAll(':', '-');
  }

  static String _uniquePath(String dir, String preferredName, {required bool isDirectory}) {
    var candidate = p.join(dir, preferredName);
    final type = FileSystemEntity.typeSync(candidate, followLinks: false);
    if (type != FileSystemEntityType.file && type != FileSystemEntityType.directory) {
      return candidate;
    }

    final baseName = p.basenameWithoutExtension(preferredName);
    final ext = p.extension(preferredName);
    var index = 1;
    while (true) {
      final numberedName = ext.isEmpty ? '$baseName $index' : '$baseName $index$ext';
      candidate = p.join(dir, numberedName);
      final t = FileSystemEntity.typeSync(candidate, followLinks: false);
      if (t != FileSystemEntityType.file && t != FileSystemEntityType.directory) {
        return candidate;
      }
      index++;
    }
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(p.join(destination.path, name)));
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, name));
      }
    }
  }
}

