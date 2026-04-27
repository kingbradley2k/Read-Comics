import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf_render/pdf_render_widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/comic_models.dart';
import '../models/reading_preferences.dart';
import '../services/comic_page_extractor.dart';

/// Renders a single comic page. Handles images (memory/file) and PDF.
class ComicPageView extends StatelessWidget {
  final ComicChapter chapter;
  final int pageIndex;
  final PageFitMode fitMode;

  const ComicPageView({
    super.key,
    required this.chapter,
    required this.pageIndex,
    this.fitMode = PageFitMode.fitPage,
  });

  @override
  Widget build(BuildContext context) {
    if (chapter.format == ComicFormat.pdf) {
      return _PdfPage(chapter: chapter, pageIndex: pageIndex, fitMode: fitMode);
    }
    return _ImagePage(chapter: chapter, pageIndex: pageIndex, fitMode: fitMode);
  }
}

class _ImagePage extends StatefulWidget {
  final ComicChapter chapter;
  final int pageIndex;
  final PageFitMode fitMode;

  const _ImagePage({
    required this.chapter,
    required this.pageIndex,
    required this.fitMode,
  });

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
  Uint8List? _bytes;
  String? _filePath;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.chapter.id != widget.chapter.id) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _bytes = null;
      _filePath = null;
    });

    try {
      final filePath = await ComicPageExtractor.getPageFilePath(widget.chapter, widget.pageIndex);
      if (filePath != null) {
        setState(() {
          _filePath = filePath;
          _loading = false;
        });
        return;
      }

      final bytes = await ComicPageExtractor.getPageBytes(widget.chapter, widget.pageIndex);
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Page not found';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  BoxFit get _boxFit {
    switch (widget.fitMode) {
      case PageFitMode.fitWidth:
        return BoxFit.fitWidth;
      case PageFitMode.fitPage:
        return BoxFit.contain;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final image = _filePath != null
        ? Image.file(File(_filePath!), fit: _boxFit)
        : Image.memory(_bytes!, fit: _boxFit);

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: widget.fitMode == PageFitMode.fitWidth
            ? SizedBox(width: double.infinity, child: image)
            : image,
      ),
    );
  }
}

class _PdfPage extends StatelessWidget {
  final ComicChapter chapter;
  final int pageIndex;
  final PageFitMode fitMode;

  const _PdfPage({
    required this.chapter,
    required this.pageIndex,
    required this.fitMode,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolvePath(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return PdfDocumentLoader.openFile(
          snapshot.data!,
          documentBuilder: (context, pdfDocument, pageCount) {
            return InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: PdfPageView(
                  pdfDocument: pdfDocument,
                  pageNumber: pageIndex + 1,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _resolvePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'ReadItAll', 'Imports', chapter.sourceRelativePath);
  }
}

