import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comic_models.dart';
import '../services/comic_library_service.dart';
import '../widgets/series_thumbnail.dart';
import 'series_detail_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ComicSeries> _filterSeries(List<ComicSeries> series) {
    if (_searchQuery.isEmpty) return series;
    final query = _searchQuery.toLowerCase();
    return series
        .where((s) => s.title.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search comics...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(128)),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text('Library'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          Consumer<ComicLibraryService>(
            builder: (context, service, child) {
              if (service.isImporting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Import comics',
                onPressed: () => service.pickAndImportFiles(),
              );
            },
          ),
        ],
      ),
      body: Consumer<ComicLibraryService>(
        builder: (context, service, child) {
          if (service.lastError != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(service.lastError!), backgroundColor: Colors.red),
              );
            });
          }

          final allSeries = service.series;
          final filteredSeries = _filterSeries(allSeries);

          if (allSeries.isEmpty) {
            return const Center(child: Text('No comics. Tap + to import.'));
          }

          if (filteredSeries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No results for "$_searchQuery"',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filteredSeries.length,
            itemBuilder: (context, index) {
              final comic = filteredSeries[index];
              return _SeriesCard(series: comic);
            },
          );
        },
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  final ComicSeries series;

  const _SeriesCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ComicLibraryService>();
    final resumeChapter = service.resumeChapter(series.key);
    final progress = resumeChapter != null ? service.progressFor(resumeChapter.id) : null;
    final displayChapter = resumeChapter ?? series.chapters.first;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SeriesDetailScreen(series: series),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SeriesThumbnail(
                      chapter: displayChapter,
                      width: double.infinity,
                      height: double.infinity,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${series.chapters.length} chapter${series.chapters.length == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (resumeChapter != null && progress != null && resumeChapter.pageCount != null)
                    Text(
                      'Page ${progress.pageIndex + 1}/${resumeChapter.pageCount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

