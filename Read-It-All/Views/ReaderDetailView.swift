import SwiftUI

struct ReaderDetailView: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore
    @EnvironmentObject private var readerViewModel: ReaderViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    let chapters: [ComicChapter]
    @Binding var selectedChapterID: UUID?

    @State private var isChromeHidden = false
    @State private var showsChapterBrowser = false

    var body: some View {
        Group {
            if readerViewModel.isLoading {
                ProgressView("Opening chapter...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document = readerViewModel.document, let chapter = readerViewModel.chapter {
                readerCanvas(chapter: chapter, document: document)
            } else if let errorMessage = readerViewModel.errorMessage {
                ContentUnavailableView(
                    "Reader Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ContentUnavailableView(
                    "Open a Chapter",
                    systemImage: "book.closed",
                    description: Text("Pick a chapter from the chapter list to start reading.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderSurfaceStyle.canvasColor(for: colorScheme).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isChromeHidden ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            if isChromeHidden == false {
                ToolbarItem(placement: .principal) {
                    if let chapter = readerViewModel.chapter, let document = readerViewModel.document {
                        VStack(spacing: 2) {
                            Text(chapter.seriesTitle)
                                .font(.headline)
                            Text("\(chapter.chapterTitle) • \(readerViewModel.currentPageIndex + 1)/\(document.pageCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        toggleChapterBrowser()
                    } label: {
                        Image(systemName: "list.bullet.rectangle.portrait")
                    }
                    .disabled(chapters.isEmpty)

                    Button {
                        stepChapter(by: -1)
                    } label: {
                        Image(systemName: "backward.end.fill")
                    }
                    .disabled(previousChapter == nil)

                    Button {
                        stepChapter(by: 1)
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .disabled(nextChapter == nil)

                    Menu {
                        Picker("Reading Mode", selection: $readerViewModel.readingMode) {
                            ForEach(ReadingMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        Picker("Fit", selection: $readerViewModel.fitMode) {
                            ForEach(PageFitMode.allCases) { fitMode in
                                Text(fitMode.title).tag(fitMode)
                            }
                        }

                        Picker("Direction", selection: $readerViewModel.readingDirection) {
                            ForEach(ReadingDirection.allCases) { direction in
                                Text(direction.title).tag(direction)
                            }
                        }

                        Toggle("Show Page Strip", isOn: $readerViewModel.showsPageStrip)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: chapterBrowserSheetBinding) {
            ChapterBrowserSheet(
                chapters: chapters,
                selectedChapterID: $selectedChapterID
            )
            .environmentObject(libraryStore)
        }
        .onChange(of: selectedChapterID) { _, _ in
            showsChapterBrowser = false
            isChromeHidden = false
        }
        .animation(.easeInOut(duration: 0.2), value: isChromeHidden)
        .animation(.snappy(duration: 0.22), value: showsChapterBrowser)
    }

    private func readerCanvas(chapter: ComicChapter, document: LoadedComicDocument) -> some View {
        ZStack(alignment: .leading) {
            readerBody(document: document)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if isChromeHidden == false {
                        readerHeader(chapter: chapter, document: document)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if shouldShowPageStrip {
                        pageStrip(document: document)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

            if usesInlineChapterBrowser, showsChapterBrowser {
                Color.black.opacity(0.24)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showsChapterBrowser = false
                    }

                ChapterBrowserSidebar(
                    chapters: chapters,
                    selectedChapterID: $selectedChapterID,
                    onClose: {
                        showsChapterBrowser = false
                    }
                )
                .environmentObject(libraryStore)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(ReaderSurfaceStyle.canvasColor(for: colorScheme))
        .task(id: prefetchKey(for: document)) {
            await prefetchVisiblePages(in: document)
        }
    }

    private func readerHeader(chapter: ComicChapter, document: LoadedComicDocument) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.seriesTitle)
                    .font(.headline)
                    .foregroundStyle(ReaderSurfaceStyle.chromePrimary(for: colorScheme))
                Text("\(chapter.chapterTitle) • \(document.format.displayName) • \(document.pageCount) pages")
                    .font(.caption)
                    .foregroundStyle(ReaderSurfaceStyle.chromeSecondary(for: colorScheme))
            }

            Spacer()

            Text("Page \(readerViewModel.currentPageIndex + 1)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(ReaderSurfaceStyle.chromeSecondary(for: colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(ReaderSurfaceStyle.dividerColor(for: colorScheme))
        }
    }

    private func pageStrip(document: LoadedComicDocument) -> some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(ReaderSurfaceStyle.dividerColor(for: colorScheme))

            PageStripView(
                document: document,
                currentPageIndex: Binding(
                    get: { readerViewModel.currentPageIndex },
                    set: { readerViewModel.updateCurrentPageIndex($0) }
                ),
                fitMode: readerViewModel.fitMode
            )
            .frame(height: 116)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func readerBody(document: LoadedComicDocument) -> some View {
        switch readerViewModel.readingMode {
        case .paged:
            TabView(
                selection: Binding(
                    get: { readerViewModel.currentPageIndex },
                    set: { readerViewModel.updateCurrentPageIndex($0) }
                )
            ) {
                ForEach(Array(document.pages.enumerated()), id: \.offset) { index, page in
                    ZStack {
                        ReaderSurfaceStyle.canvasColor(for: colorScheme).ignoresSafeArea()

                        InteractiveComicPageView(
                            source: page,
                            maxPixelSize: 2800,
                            fitMode: readerViewModel.fitMode,
                            onLeadingTap: handleLeadingTap,
                            onCenterTap: toggleChrome,
                            onTrailingTap: handleTrailingTap
                        )
                        .padding(pageContentPadding)
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

        case .continuous:
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(document.pages.enumerated()), id: \.offset) { index, page in
                        AsyncComicImageView(
                            source: page,
                            maxPixelSize: 2600,
                            fitMode: readerViewModel.fitMode
                        )
                        .frame(minHeight: 320)
                        .padding(.horizontal, pageContentPadding)
                        .id(index)
                        .onAppear {
                            readerViewModel.updateCurrentPageIndex(index)
                        }
                    }
                }
                .padding(.vertical, pageContentPadding)
            }
            .overlay {
                ReaderTapZones(
                    onCenterTap: toggleChrome
                )
            }
            .background(ReaderSurfaceStyle.canvasColor(for: colorScheme))
        }
    }

    private var currentChapterIndex: Int? {
        guard let selectedChapterID else { return nil }
        return chapters.firstIndex(where: { $0.id == selectedChapterID })
    }

    private var previousChapter: ComicChapter? {
        guard let currentChapterIndex, chapters.indices.contains(currentChapterIndex - 1) else { return nil }
        return chapters[currentChapterIndex - 1]
    }

    private var nextChapter: ComicChapter? {
        guard let currentChapterIndex, chapters.indices.contains(currentChapterIndex + 1) else { return nil }
        return chapters[currentChapterIndex + 1]
    }

    private var shouldShowPageStrip: Bool {
        readerViewModel.showsPageStrip && isChromeHidden == false
    }

    private var usesInlineChapterBrowser: Bool {
        horizontalSizeClass == .regular
    }

    private var chapterBrowserSheetBinding: Binding<Bool> {
        Binding(
            get: { usesInlineChapterBrowser == false && showsChapterBrowser },
            set: { showsChapterBrowser = $0 }
        )
    }

    private var pageContentPadding: CGFloat {
        isChromeHidden ? 0 : 12
    }

    private func prefetchKey(for document: LoadedComicDocument) -> String {
        let chapterID = readerViewModel.chapter?.id.uuidString ?? "none"
        return [
            chapterID,
            String(readerViewModel.currentPageIndex),
            String(document.pageCount),
            readerViewModel.readingMode.rawValue
        ].joined(separator: "::")
    }

    private func prefetchVisiblePages(in document: LoadedComicDocument) async {
        guard document.pages.isEmpty == false else { return }

        let currentIndex = min(max(readerViewModel.currentPageIndex, 0), document.pages.count - 1)
        let lowerBound = max(0, currentIndex - 1)
        let upperBound = min(document.pages.count - 1, currentIndex + 3)
        let sources = Array(document.pages[lowerBound...upperBound])

        await ComicPageRenderer.shared.prefetchImages(
            for: sources,
            maxPixelSize: readerViewModel.readingMode == .paged ? 2800 : 2600
        )
    }

    private func handleLeadingTap() {
        if readerViewModel.readingDirection == .rightToLeft {
            readerViewModel.advancePage()
        } else {
            readerViewModel.rewindPage()
        }
    }

    private func handleTrailingTap() {
        if readerViewModel.readingDirection == .rightToLeft {
            readerViewModel.rewindPage()
        } else {
            readerViewModel.advancePage()
        }
    }

    private func toggleChrome() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isChromeHidden.toggle()
            if isChromeHidden {
                showsChapterBrowser = false
            }
        }
    }

    private func toggleChapterBrowser() {
        guard chapters.isEmpty == false else { return }
        withAnimation(.snappy(duration: 0.22)) {
            showsChapterBrowser.toggle()
        }
    }

    private func stepChapter(by delta: Int) {
        guard let currentChapterIndex else { return }
        let nextIndex = currentChapterIndex + delta
        guard chapters.indices.contains(nextIndex) else { return }
        selectedChapterID = chapters[nextIndex].id
    }
}

private struct ReaderTapZones: View {
    var onLeadingTap: (() -> Void)? = nil
    let onCenterTap: () -> Void
    var onTrailingTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onLeadingTap?()
                }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onCenterTap)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onTrailingTap?()
                }
        }
    }
}

private struct ChapterBrowserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let chapters: [ComicChapter]
    @Binding var selectedChapterID: UUID?

    var body: some View {
        NavigationStack {
            ChapterBrowserList(
                chapters: chapters,
                selectedChapterID: $selectedChapterID
            )
            .environmentObject(libraryStore)
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ChapterBrowserSidebar: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let chapters: [ComicChapter]
    @Binding var selectedChapterID: UUID?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chapters")
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            ChapterBrowserList(
                chapters: chapters,
                selectedChapterID: $selectedChapterID
            )
            .environmentObject(libraryStore)
        }
        .frame(width: 320)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.leading, 16)
        .padding(.vertical, 16)
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
    }
}

private struct ChapterBrowserList: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let chapters: [ComicChapter]
    @Binding var selectedChapterID: UUID?

    @State private var chapterPendingDeletion: ComicChapter?

    var body: some View {
        List(chapters, selection: $selectedChapterID) { chapter in
            Button {
                selectedChapterID = chapter.id
            } label: {
                HStack(spacing: 12) {
                    ChapterThumbnailView(
                        chapter: chapter,
                        documentURL: libraryStore.storageURL(for: chapter)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(chapter.chapterTitle)
                            .font(.headline)
                            .multilineTextAlignment(.leading)

                        Text(chapter.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if selectedChapterID == chapter.id {
                            Text("Currently open")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tag(chapter.id)
            .contextMenu {
                Button(role: .destructive) {
                    chapterPendingDeletion = chapter
                } label: {
                    Label("Delete Chapter", systemImage: "trash")
                }
            }
        }
        .listStyle(.plain)
        .confirmationDialog(
            "Delete Chapter?",
            isPresented: chapterDeletionBinding,
            titleVisibility: .visible
        ) {
            if let chapterPendingDeletion {
                Button("Delete Chapter", role: .destructive) {
                    deleteChapter(chapterPendingDeletion)
                    self.chapterPendingDeletion = nil
                }
            }

            Button("Cancel", role: .cancel) {
                chapterPendingDeletion = nil
            }
        } message: {
            if let chapterPendingDeletion {
                Text("Delete \(chapterPendingDeletion.chapterTitle) from this comic.")
            }
        }
    }

    private var chapterDeletionBinding: Binding<Bool> {
        Binding(
            get: { chapterPendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    chapterPendingDeletion = nil
                }
            }
        )
    }

    private func deleteChapter(_ chapter: ComicChapter) {
        if selectedChapterID == chapter.id {
            selectedChapterID = replacementChapterID(afterDeleting: chapter.id)
        }

        libraryStore.deleteChapter(chapter)
    }

    private func replacementChapterID(afterDeleting chapterID: UUID) -> UUID? {
        guard let currentIndex = chapters.firstIndex(where: { $0.id == chapterID }) else {
            return selectedChapterID
        }

        let remainingChapters = chapters.filter { $0.id != chapterID }
        guard remainingChapters.isEmpty == false else { return nil }

        if remainingChapters.indices.contains(currentIndex) {
            return remainingChapters[currentIndex].id
        }

        return remainingChapters.last?.id
    }
}

private struct PageStripView: View {
    @Environment(\.colorScheme) private var colorScheme

    let document: LoadedComicDocument
    @Binding var currentPageIndex: Int
    let fitMode: PageFitMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(Array(document.pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 6) {
                        AsyncComicImageView(
                            source: page,
                            maxPixelSize: 320,
                            fitMode: fitMode
                        )
                        .frame(width: 64, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(index == currentPageIndex ? Color.accentColor : .clear, lineWidth: 2)
                        }

                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(ReaderSurfaceStyle.chromeSecondary(for: colorScheme))
                    }
                    .onTapGesture {
                        currentPageIndex = index
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(ReaderSurfaceStyle.pageStripBackdrop(for: colorScheme))
    }
}
