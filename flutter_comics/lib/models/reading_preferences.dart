import 'package:shared_preferences/shared_preferences.dart';

enum ReadingDirection {
  leftToRight,
  rightToLeft,
}

enum PageFitMode {
  fitWidth,
  fitPage,
}

/// Lightweight reading preferences using SharedPreferences (no code gen needed).
class ReadingPreferences {
  static const _keyDirection = 'readcomics.direction';
  static const _keyFitMode = 'readcomics.fitMode';
  static const _keyUseSystemTheme = 'readcomics.useSystemTheme';
  static const _keyDarkMode = 'readcomics.darkMode';

  static Future<ReadingPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ReadingPreferences._(
      direction: ReadingDirection.values[prefs.getInt(_keyDirection) ?? 0],
      fitMode: PageFitMode.values[prefs.getInt(_keyFitMode) ?? 1],
      useSystemTheme: prefs.getBool(_keyUseSystemTheme) ?? true,
      darkMode: prefs.getBool(_keyDarkMode) ?? false,
    );
  }

  ReadingDirection direction;
  PageFitMode fitMode;
  bool useSystemTheme;
  bool darkMode;

  ReadingPreferences._({
    required this.direction,
    required this.fitMode,
    required this.useSystemTheme,
    required this.darkMode,
  });

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDirection, direction.index);
    await prefs.setInt(_keyFitMode, fitMode.index);
    await prefs.setBool(_keyUseSystemTheme, useSystemTheme);
    await prefs.setBool(_keyDarkMode, darkMode);
  }
}

