import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comic_models.dart';
import '../services/comic_library_service.dart';
import '../widgets/series_thumbnail.dart';
import 'reader_screen.dart';

class SeriesDetailScreen extends StatelessWidget {
  final ComicSeries series;

  const SeriesDetailScreen({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ComicLibraryService>();
    final chapters = service.chaptersInSeries(series.key);
    final resumeChapter = service.resumeChapter(series.key);

    return Scaffold(
      appBar: AppBar(
        title: Text(series.title),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chapters.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SeriesHeader(
              series: series,
              resumeChapter: resumeChapter,
              onResume: resumeChapter != null
                  ? () => _openReader(context, resumeChapter)
                  : null,
            );
          }
          final chapter = chapters[index - 1];
          return _ChapterTile(chapter: chapter, onTap: () => _openReader(context, chapter));
        },
      ),
    );
  }

  void _openReader(BuildContext context, ComicChapter chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => ReaderScreen(chapter: chapter)),
    );
  }
}

class _SeriesHeader extends StatelessWidget {
  final ComicSeries series;
  final ComicChapter? resumeChapter;
  final VoidCallback? onResume;

  const _SeriesHeader({
    required this.series,
    this.resumeChapter,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (series.chapters.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: SeriesThumbnail(
                chapter: resumeChapter ?? series.chapters.first,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          series.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '${series.chapters.length} chapter${series.chapters.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        if (onResume != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume Reading'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Text(
          'Chapters',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  final ComicChapter chapter;
  final VoidCallback onTap;

  const _ChapterTile({required this.chapter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ComicLibraryService>();
    final progress = service.progressFor(chapter.id);
    final hasProgress = progress.pageIndex > 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SeriesThumbnail(
          chapter: chapter,
          width: 56,
          height: 72,
        ),
      ),
      title: Text(chapter.chapterTitle),
      subtitle: Text(chapter.subtitle),
      trailing: hasProgress && chapter.pageCount != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${progress.pageIndex + 1}/${chapter.pageCount}'),
                const SizedBox(height: 4),
                SizedBox(
                  width: 80,
                  child: LinearProgressIndicator(
                    value: chapter.pageCount! > 0 ? progress.pageIndex / chapter.pageCount! : 0,
                    backgroundColor: Colors.grey[300],
                  ),
                ),
              ],
            )
          : null,
      onTap: onTap,
    );
  }
}

