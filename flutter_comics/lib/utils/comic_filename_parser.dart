import 'dart:io';

class ParsedResult {
  final String seriesKey;
  final String seriesTitle;
  final String chapterTitle;
  final double? issueNumber;

  ParsedResult({
    required this.seriesKey,
    required this.seriesTitle,
    required this.chapterTitle,
    this.issueNumber,
  });
}

class ComicFilenameParser {
  static final _genericNames = <String>{
    '',
    'books',
    'chapter',
    'chapters',
    'comics',
    'desktop',
    'documents',
    'downloads',
    'files',
    'imports',
    'library',
    'manga',
    'reader',
    'storage',
  };

  static ParsedResult parse(File file) {
    final rawName = _basenameWithoutExtension(file.path);
    final cleanedName = _normalize(rawName);
    final issueNumber = _extractIssueNumber(cleanedName);

    final parentTitle = _bestParentTitle(file);
    final seriesFromFilename = _seriesTitleFromFilename(cleanedName, issueNumber);
    final preferredSeriesTitle = _resolveSeriesTitle(
      cleanedName: cleanedName,
      seriesFromFilename: seriesFromFilename,
      parentTitle: parentTitle,
    );

    final chapterTitle = _makeChapterTitle(
      cleanedName,
      issueNumber,
      preferredSeriesTitle,
    );

    final key = _normalizedKey(preferredSeriesTitle);

    return ParsedResult(
      seriesKey: key.isEmpty ? _uuid() : key,
      seriesTitle: preferredSeriesTitle,
      chapterTitle: chapterTitle,
      issueNumber: issueNumber,
    );
  }

  static String _resolveSeriesTitle({
    required String cleanedName,
    String? seriesFromFilename,
    String? parentTitle,
  }) {
    if (seriesFromFilename != null && !_isGenericContainerName(seriesFromFilename)) {
      return seriesFromFilename;
    }

    if (parentTitle != null && _isLikelyStandaloneChapterName(cleanedName)) {
      return parentTitle;
    }

    if (parentTitle != null && !_isGenericContainerName(parentTitle)) {
      return parentTitle;
    }

    return cleanedName.isEmpty ? 'Imported Comic' : cleanedName;
  }

  static String _makeChapterTitle(String cleanedName, double? issueNumber, String seriesTitle) {
    final explicitChapterPattern = RegExp(
      r'^(chapter|issue|book|part|volume|vol\.?|episode|ep\.?)\s+.*$',
      caseSensitive: false,
    );
    if (explicitChapterPattern.hasMatch(cleanedName)) {
      return cleanedName;
    }

    if (cleanedName.toLowerCase() != seriesTitle.toLowerCase()) {
      return cleanedName;
    }

    if (issueNumber != null) {
      if (issueNumber == issueNumber.roundToDouble()) {
        return 'Issue ${issueNumber.toInt()}';
      }
      return 'Issue $issueNumber';
    }

    return cleanedName.isEmpty ? 'Untitled Chapter' : cleanedName;
  }

  static String? _seriesTitleFromFilename(String cleanedName, double? issueNumber) {
    if (issueNumber == null) {
      return _isLikelyStandaloneChapterName(cleanedName) ? null : cleanedName;
    }

    final numericPattern = RegExp(r'(.*?)(?:^|\s)(\d{1,4}(?:\.\d+)?)\s*$');
    final match = numericPattern.firstMatch(cleanedName);
    if (match == null) {
      return _isLikelyStandaloneChapterName(cleanedName) ? null : cleanedName;
    }

    final prefix = match.group(1)?.trim() ?? '';
    if (prefix.isEmpty) return null;
    return _isLikelyStandaloneChapterName(prefix) ? null : prefix;
  }

  static String? _bestParentTitle(File file) {
    final directParent = _normalize(file.parent.path.split(Platform.pathSeparator).last);
    if (directParent.isNotEmpty && !_isGenericContainerName(directParent)) {
      return directParent;
    }

    final grandParentPath = file.parent.parent;
    if (grandParentPath.path == file.parent.path) return null;
    final grandParent = _normalize(grandParentPath.path.split(Platform.pathSeparator).last);
    if (grandParent.isNotEmpty && !_isGenericContainerName(grandParent)) {
      return grandParent;
    }

    return null;
  }

  static String _normalize(String value) {
    return value
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'\[[^\]]*\]'), (_) => ' ')
        .replaceAllMapped(RegExp(r'\([^\)]*\)'), (_) => ' ')
        .replaceAllMapped(RegExp(r'\s+'), (_) => ' ')
        .trim();
  }

  static double? _extractIssueNumber(String value) {
    final patterns = [
      RegExp(r'(?:^|\s)(\d{1,4}(?:\.\d+)?)\s*$'),
      RegExp(r'(?:^|\s)(\d{1,4}(?:\.\d+)?)(?:\s+of\s+\d+)?(?:\s|$)'),
    ];

    for (final pattern in patterns) {
      final matches = pattern.allMatches(value).toList();
      if (matches.isEmpty) continue;
      final match = matches.last;
      final group = match.group(1);
      if (group != null) {
        final parsed = double.tryParse(group);
        if (parsed != null) return parsed;
      }
    }

    return null;
  }

  static bool _isLikelyStandaloneChapterName(String value) {
    final normalizedValue = value.trim();
    if (normalizedValue.isEmpty) return true;

    final patterns = [
      RegExp(r'^\d{1,4}(?:\.\d+)?$'),
      RegExp(r'^(chapter|issue|book|part|volume|vol\.?|episode|ep\.?)\s*\d.*$', caseSensitive: false),
      RegExp(r'^(chapter|issue|book|part|volume|vol\.?|episode|ep\.?)\b.*$', caseSensitive: false),
      RegExp(r'^\d{1,4}(?:\.\d+)?\s+of\s+\d{1,4}$', caseSensitive: false),
    ];

    return patterns.any((p) => p.hasMatch(normalizedValue));
  }

  static bool _isGenericContainerName(String value) {
    final key = _normalizedKey(value);
    return _genericNames.contains(key) || _isLikelyStandaloneChapterName(value);
  }

  static String _normalizedKey(String value) {
    return value
        .toLowerCase()
        .replaceAllMapped(RegExp(r'[^a-z0-9]+'), (_) => '-')
        .replaceAll(RegExp(r'^-+|+-+$'), '');
  }

  static String _basenameWithoutExtension(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0) return name;
    return name.substring(0, dotIndex);
  }

  static String _uuid() {
    // Simple UUID v4-like generator
    final random = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    return 'import-$random';
  }
}

