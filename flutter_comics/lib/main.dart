import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/comic_models.dart';
import 'models/reading_preferences.dart';
import 'services/comic_library_service.dart';
import 'screens/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  Hive.registerAdapter(ComicChapterAdapter());
  Hive.registerAdapter(ComicProgressAdapter());
  await Hive.openBox<ComicChapter>('chapters');
  await Hive.openBox<ComicProgress>('progress');
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ReadingPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await ReadingPreferences.load();
    setState(() => _prefs = prefs);
  }

  ThemeMode get _themeMode {
    final prefs = _prefs;
    if (prefs == null) return ThemeMode.system;
    if (prefs.useSystemTheme) return ThemeMode.system;
    return prefs.darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final service = ComicLibraryService();
        service.init();
        return service;
      },
      child: MaterialApp(
        title: 'Read Comics Flutter',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: _themeMode,
        home: const LibraryScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

