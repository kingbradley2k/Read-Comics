import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/comic_models.dart';
import '../models/reading_preferences.dart';
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
  ReadingPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    final service = context.read<ComicLibraryService>();
    final progress = service.progressFor(widget.chapter.id);
    _currentPage = progress.pageIndex;
    _pageController = PageController(initialPage: _currentPage);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await ReadingPreferences.load();
    setState(() => _prefs = prefs);
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

  void _toggleDirection() {
    if (_prefs == null) return;
    setState(() {
      _prefs!.direction = _prefs!.direction == ReadingDirection.leftToRight
          ? ReadingDirection.rightToLeft
          : ReadingDirection.leftToRight;
    });
    _prefs!.save();
  }

  void _toggleFitMode() {
    if (_prefs == null) return;
    setState(() {
      _prefs!.fitMode = _prefs!.fitMode == PageFitMode.fitWidth
          ? PageFitMode.fitPage
          : PageFitMode.fitWidth;
    });
    _prefs!.save();
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = widget.chapter.pageCount ?? 1;
    final theme = Theme.of(context);
    final prefs = _prefs;
    final isRtl = prefs?.direction == ReadingDirection.rightToLeft;

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
              reverse: isRtl,
              itemBuilder: (context, index) {
                return ComicPageView(
                  chapter: widget.chapter,
                  pageIndex: index,
                  fitMode: prefs?.fitMode ?? PageFitMode.fitPage,
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
                      if (prefs != null)
                        IconButton(
                          icon: Icon(
                            isRtl ? Icons.format_textdirection_r_to_l : Icons.format_textdirection_l_to_r,
                            color: Colors.white,
                          ),
                          tooltip: isRtl ? 'RTL' : 'LTR',
                          onPressed: _toggleDirection,
                        ),
                      if (prefs != null)
                        IconButton(
                          icon: Icon(
                            prefs.fitMode == PageFitMode.fitWidth ? Icons.fit_screen : Icons.aspect_ratio,
                            color: Colors.white,
                          ),
                          tooltip: prefs.fitMode == PageFitMode.fitWidth ? 'Fit Width' : 'Fit Page',
                          onPressed: _toggleFitMode,
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

