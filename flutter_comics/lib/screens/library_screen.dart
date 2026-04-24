import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/comic_library_service.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {
            // File picker import
          }),
        ],
      ),
      body: Consumer<ComicLibraryService>(
        builder: (context, service, child) {
          final series = service.series;
          if (series.isEmpty) {
            return const Center(child: Text('No comics. Tap + to import.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: series.length,
            itemBuilder: (context, index) {
              final comic = series[index];
              return Card(
                child: Column(
                  children: [
                    // Thumbnail placeholder
                    Container(height: 150, color: Colors.grey[300], child: const Icon(Icons.image)),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(comic.title, style: Theme.of(context).textTheme.titleMedium),
                          Text('${comic.chapters.length} chapters'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

