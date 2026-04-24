import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'models/comic_models.dart';
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
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ComicLibraryService(),
      child: MaterialApp(
        title: 'Read Comics Flutter',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: LibraryScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

