import 'package:flutter/foundation.dart';
import '../models/comic_models.dart';

class ComicLibraryService extends ChangeNotifier {
  final List<ComicChapter> _chapters = [];
  final Map<String, ComicProgress> _progressById = {};

  List<ComicChapter> get chapters => _chapters;
  List<ComicSeries> get series {
    // Group and sort logic ported from Swift
    final grouped = <String, List<ComicChapter>>{};
    for (var chapter in _chapters) {
      grouped.putIfAbsent(chapter.seriesKey, () => []).add(chapter);
    }
    return grouped.entries
        .map((e) => ComicSeries(key: e.key, title: e.value.first.seriesTitle, chapters: e.value))
        .toList()
        ..sort((a, b) => a.title.compareTo(b.title));
  }

  Future<void> importComic(String filePath) async {
    // TODO: Copy file, parse filename, inspect pages, add chapter
    notifyListeners();
  }

  void updateProgress(String chapterId, int page) {
    // TODO: Save progress
    notifyListeners();
  }
}

