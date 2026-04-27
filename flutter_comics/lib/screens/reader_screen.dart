import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comic_models.dart';
import '../services/comic_library_service.dart';
import '../widgets/comic_page_view.dart';

class ReaderScreen extends StatefulWidget {
  final ComicChapter chapter;

  const ReaderScreen({super.key, required this.chapter});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pageController;
  late int _currentPage;
  bool _controlsVisible = true;

  @override
  void initState() {
    super.initState();
    final service = context.read<ComicLibraryService>();
    final progress = service.progressFor(widget.chapter.id);
    _currentPage = progress.pageIndex;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _saveProgress() {
    final service = context.read<ComicLibraryService>();
    service.updateProgress(widget.chapter.id, _currentPage);
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _saveProgress();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.chapter.pageCount ?? 1;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Page viewer
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: pageCount,
              itemBuilder: (context, index) {
                return ComicPageView(
                  chapter: widget.chapter,
                  pageIndex: index,
                );
              },
            ),

            // Top app bar
            AnimatedSlide(
              offset: _controlsVisible ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 250),
              child: Container(
                color: Colors.black54,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          widget.chapter.chapterTitle,
                          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '${_currentPage + 1} / $pageCount',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom progress slider
            AnimatedSlide(
              offset: _controlsVisible ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 250),
              child: Container(
                color: Colors.black54,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: Colors.white),
                          onPressed: _currentPage > 0
                              ? () => _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  )
                              : null,
                        ),
                        Expanded(
                          child: Slider(
                            value: _currentPage.toDouble(),
                            min: 0,
                            max: (pageCount - 1).toDouble(),
                            divisions: pageCount > 1 ? pageCount - 1 : 1,
                            label: '${_currentPage + 1}',
                            activeColor: Colors.white,
                            inactiveColor: Colors.white30,
                            onChanged: (value) {
                              final page = value.round();
                              _pageController.jumpToPage(page);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white),
                          onPressed: _currentPage < pageCount - 1
                              ? () => _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

