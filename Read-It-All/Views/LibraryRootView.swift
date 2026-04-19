import SwiftUI
import UniformTypeIdentifiers

private enum LibraryLayoutStyle: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: return "Grid"
        case .list: return "List"
        }
    }

    var toggleSystemImage: String {
        switch self {
        case .grid: return "list.bullet"
        case .list: return "square.grid.2x2"
        }
    }
}

private enum LibrarySortStyle: String, CaseIterable, Identifiable {
    case titleAscending
    case titleDescending
    case recentlyRead
    case recentlyAdded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .titleAscending: return "Title A-Z"
        case .titleDescending: return "Title Z-A"
        case .recentlyRead: return "Recently Read"
        case .recentlyAdded: return "Recently Added"
        }
    }
}

struct LibraryRootView: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore
    @EnvironmentObject private var readerViewModel: ReaderViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @AppStorage("readcomics.library.layout") private var libraryLayoutRaw = LibraryLayoutStyle.grid.rawValue
    @AppStorage("readcomics.library.sort") private var librarySortRaw = LibrarySortStyle.titleAscending.rawValue

    @State private var selectedSeriesID: String?
    @State private var selectedChapterID: UUID?
    @State private var isImporting = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactBody
            } else {
                regularBody
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: UTType.comicImportTypes,
            allowsMultipleSelection: true
        ) { result in
            Task {
                switch result {
                case let .success(urls):
                    let imported = await libraryStore.importItems(from: urls)
                    guard let first = imported.first else { return }
                    if horizontalSizeClass == .compact {
                        return
                    }
                    activateSeries(first.seriesKey, preferredChapterID: first.id)
                case let .failure(error):
                    libraryStore.lastImportError = error.localizedDescription
                }
            }
        }
        .alert("Import Problem", isPresented: importErrorBinding) {
            Button("OK", role: .cancel) {
                libraryStore.lastImportError = nil
            }
        } message: {
            Text(libraryStore.lastImportError ?? "")
        }
        .onChange(of: libraryStore.series) { _, _ in
            validateRegularSelection()
        }
        .onChange(of: selectedChapterID) { _, newValue in
            guard horizontalSizeClass != .compact else { return }
            Task {
                await readerViewModel.open(libraryStore.chapter(id: newValue))
            }
        }
        .task(id: horizontalSizeClass) {
            if horizontalSizeClass != .compact {
                validateRegularSelection()
                await readerViewModel.open(libraryStore.chapter(id: selectedChapterID))
            }
        }
    }

    private var compactBody: some View {
        NavigationStack {
            ComicsBrowserPane(
                series: sortedSeries,
                selectedSeriesID: nil,
                layoutStyle: currentLayoutStyle,
                sortStyle: currentSortStyle,
                showsNavigationLinks: true,
                onImport: {
                    isImporting = true
                },
                onToggleLayout: toggleLayoutStyle,
                onSortChange: updateSortStyle,
                onSelect: { _ in }
            )
        }
    }

    private var regularBody: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ComicsBrowserPane(
                series: sortedSeries,
                selectedSeriesID: selectedSeriesID,
                layoutStyle: currentLayoutStyle,
                sortStyle: currentSortStyle,
                showsNavigationLinks: false,
                onImport: {
                    isImporting = true
                },
                onToggleLayout: toggleLayoutStyle,
                onSortChange: updateSortStyle,
                onSelect: { series in
                    activateSeries(series.id)
                }
            )
        } content: {
            if let selectedSeries {
                ChapterListPane(
                    chapters: selectedSeries.chapters,
                    selectedChapterID: $selectedChapterID,
                    title: selectedSeries.title
                )
            } else {
                ComicSelectionPlaceholder(
                    title: "Choose a Comic",
                    systemImage: "books.vertical",
                    message: "Select a comic to resume reading or choose a starting chapter."
                )
            }
        } detail: {
            if let selectedSeries {
                ReaderDetailView(
                    chapters: selectedSeries.chapters,
                    selectedChapterID: $selectedChapterID
                )
            } else {
                ComicSelectionPlaceholder(
                    title: "Choose a Comic",
                    systemImage: "book.closed",
                    message: "Your last-read chapter will open automatically when a comic has reading history."
                )
            }
        }
    }

    private var currentLayoutStyle: LibraryLayoutStyle {
        LibraryLayoutStyle(rawValue: libraryLayoutRaw) ?? .grid
    }

    private var currentSortStyle: LibrarySortStyle {
        LibrarySortStyle(rawValue: librarySortRaw) ?? .titleAscending
    }

    private var selectedSeries: ComicSeries? {
        guard let selectedSeriesID else { return nil }
        return libraryStore.series.first(where: { $0.id == selectedSeriesID })
    }

    private var sortedSeries: [ComicSeries] {
        switch currentSortStyle {
        case .titleAscending:
            return libraryStore.series.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }

        case .titleDescending:
            return libraryStore.series.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
            }

        case .recentlyRead:
            return libraryStore.series.sorted { lhs, rhs in
                let lhsDate = libraryStore.latestReadDate(in: lhs.id) ?? .distantPast
                let rhsDate = libraryStore.latestReadDate(in: rhs.id) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

        case .recentlyAdded:
            return libraryStore.series.sorted { lhs, rhs in
                let lhsDate = libraryStore.latestImportDate(in: lhs.id) ?? .distantPast
                let rhsDate = libraryStore.latestImportDate(in: rhs.id) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { libraryStore.lastImportError != nil },
            set: { newValue in
                if newValue == false {
                    libraryStore.lastImportError = nil
                }
            }
        )
    }

    private func toggleLayoutStyle() {
        libraryLayoutRaw = currentLayoutStyle == .grid ? LibraryLayoutStyle.list.rawValue : LibraryLayoutStyle.grid.rawValue
    }

    private func updateSortStyle(_ sortStyle: LibrarySortStyle) {
        librarySortRaw = sortStyle.rawValue
    }

    private func activateSeries(_ seriesID: String, preferredChapterID: UUID? = nil) {
        selectedSeriesID = seriesID

        if let preferredChapterID,
           libraryStore.chapters(in: seriesID).contains(where: { $0.id == preferredChapterID }) {
            selectedChapterID = preferredChapterID
            return
        }

        selectedChapterID = libraryStore.resumeChapter(in: seriesID)?.id
    }

    private func validateRegularSelection() {
        guard let selectedSeriesID else {
            selectedChapterID = nil
            return
        }

        guard libraryStore.series.contains(where: { $0.id == selectedSeriesID }) else {
            self.selectedSeriesID = nil
            self.selectedChapterID = nil
            return
        }

        let chapters = libraryStore.chapters(in: selectedSeriesID)
        if let selectedChapterID,
           chapters.contains(where: { $0.id == selectedChapterID }) {
            return
        }

        self.selectedChapterID = libraryStore.resumeChapter(in: selectedSeriesID)?.id
    }
}

private struct ComicsBrowserPane: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let series: [ComicSeries]
    let selectedSeriesID: String?
    let layoutStyle: LibraryLayoutStyle
    let sortStyle: LibrarySortStyle
    let showsNavigationLinks: Bool
    let onImport: () -> Void
    let onToggleLayout: () -> Void
    let onSortChange: (LibrarySortStyle) -> Void
    let onSelect: (ComicSeries) -> Void

    @State private var seriesPendingDeletion: ComicSeries?

    var body: some View {
        Group {
            if series.isEmpty {
                ContentUnavailableView(
                    "No Comics Yet",
                    systemImage: "books.vertical",
                    description: Text("Import CBZ, CBR, PDF, ZIP, RAR, or image folders to populate the library.")
                )
            } else {
                switch layoutStyle {
                case .grid:
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 16)],
                            spacing: 16
                        ) {
                            ForEach(series) { comicSeries in
                                seriesGridEntry(for: comicSeries)
                            }
                        }
                        .padding(16)
                    }

                case .list:
                    List {
                        ForEach(series) { comicSeries in
                            seriesListEntry(for: comicSeries)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Read Comics")
        .confirmationDialog(
            "Delete Comic?",
            isPresented: seriesDeletionBinding,
            titleVisibility: .visible
        ) {
            if let seriesPendingDeletion {
                Button("Delete Comic", role: .destructive) {
                    libraryStore.deleteSeries(seriesPendingDeletion)
                    self.seriesPendingDeletion = nil
                }
            }

            Button("Cancel", role: .cancel) {
                seriesPendingDeletion = nil
            }
        } message: {
            if let seriesPendingDeletion {
                Text("Delete \(seriesPendingDeletion.title) and all of its imported chapters from this device.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onImport()
                } label: {
                    Label("Import", systemImage: "plus")
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    onToggleLayout()
                } label: {
                    Image(systemName: layoutStyle.toggleSystemImage)
                }

                Menu {
                    Picker("Sort", selection: Binding(get: { sortStyle }, set: onSortChange)) {
                        ForEach(LibrarySortStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
        }
    }

    @ViewBuilder
    private func seriesGridEntry(for comicSeries: ComicSeries) -> some View {
        if showsNavigationLinks {
            NavigationLink {
                SeriesReaderScreen(seriesID: comicSeries.id)
            } label: {
                SeriesGridCard(series: comicSeries, isSelected: false)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    seriesPendingDeletion = comicSeries
                } label: {
                    Label("Delete Comic", systemImage: "trash")
                }
            }
        } else {
            Button {
                onSelect(comicSeries)
            } label: {
                SeriesGridCard(series: comicSeries, isSelected: selectedSeriesID == comicSeries.id)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    seriesPendingDeletion = comicSeries
                } label: {
                    Label("Delete Comic", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func seriesListEntry(for comicSeries: ComicSeries) -> some View {
        if showsNavigationLinks {
            NavigationLink {
                SeriesReaderScreen(seriesID: comicSeries.id)
            } label: {
                SeriesListRow(series: comicSeries, isSelected: false)
            }
            .contextMenu {
                Button(role: .destructive) {
                    seriesPendingDeletion = comicSeries
                } label: {
                    Label("Delete Comic", systemImage: "trash")
                }
            }
        } else {
            Button {
                onSelect(comicSeries)
            } label: {
                SeriesListRow(series: comicSeries, isSelected: selectedSeriesID == comicSeries.id)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    seriesPendingDeletion = comicSeries
                } label: {
                    Label("Delete Comic", systemImage: "trash")
                }
            }
        }
    }

    private var seriesDeletionBinding: Binding<Bool> {
        Binding(
            get: { seriesPendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    seriesPendingDeletion = nil
                }
            }
        )
    }
}

private struct SeriesGridCard: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let series: ComicSeries
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SeriesThumbnailView(
                series: series,
                size: CGSize(width: 180, height: 236)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(series.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(primaryStatusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(secondaryStatusLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
        }
    }

    private var resumeState: (chapter: ComicChapter, progress: ComicProgress)? {
        libraryStore.resumeState(in: series.id)
    }

    private var primaryStatusLine: String {
        if let resumeState {
            return "Resume \(resumeState.chapter.chapterTitle)"
        }
        if let firstChapter = series.chapters.first {
            return "Start with \(firstChapter.chapterTitle)"
        }
        return "No chapters available"
    }

    private var secondaryStatusLine: String {
        if let resumeState, let pageCount = resumeState.chapter.pageCount {
            let pageNumber = min(resumeState.progress.pageIndex + 1, pageCount)
            return "Page \(pageNumber)/\(pageCount) • \(series.chapters.count) chapter\(series.chapters.count == 1 ? "" : "s")"
        }
        return "\(series.chapters.count) chapter\(series.chapters.count == 1 ? "" : "s")"
    }
}

private struct SeriesListRow: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let series: ComicSeries
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            SeriesThumbnailView(
                series: series,
                size: CGSize(width: 76, height: 102)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(series.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(primaryStatusLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(secondaryStatusLine)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
        }
    }

    private var resumeState: (chapter: ComicChapter, progress: ComicProgress)? {
        libraryStore.resumeState(in: series.id)
    }

    private var primaryStatusLine: String {
        if let resumeState {
            return "Resume \(resumeState.chapter.chapterTitle)"
        }
        if let firstChapter = series.chapters.first {
            return "Choose a chapter or start with \(firstChapter.chapterTitle)"
        }
        return "No chapters available"
    }

    private var secondaryStatusLine: String {
        if let resumeState, let pageCount = resumeState.chapter.pageCount {
            let pageNumber = min(resumeState.progress.pageIndex + 1, pageCount)
            return "Page \(pageNumber)/\(pageCount) • \(series.chapters.count) chapter\(series.chapters.count == 1 ? "" : "s")"
        }
        return "\(series.chapters.count) chapter\(series.chapters.count == 1 ? "" : "s")"
    }
}

private struct SeriesThumbnailView: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let series: ComicSeries
    let size: CGSize

    var body: some View {
        if let representativeChapter {
            ChapterThumbnailView(
                chapter: representativeChapter,
                documentURL: libraryStore.storageURL(for: representativeChapter),
                preferredPageIndex: preferredPageIndex,
                size: size
            )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemFill))
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: "book.pages")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var representativeChapter: ComicChapter? {
        libraryStore.resumeChapter(in: series.id) ?? series.chapters.first
    }

    private var preferredPageIndex: Int {
        guard let representativeChapter else { return 0 }
        return libraryStore.storedProgress(for: representativeChapter.id)?.pageIndex ?? 0
    }
}

struct SeriesReaderScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var libraryStore: ComicLibraryStore
    @EnvironmentObject private var readerViewModel: ReaderViewModel

    let seriesID: String
    var initialChapterID: UUID? = nil

    @State private var selectedChapterID: UUID?
    @State private var hasSeededSelection = false

    var body: some View {
        Group {
            if let series {
                if selectedChapterID == nil {
                    ChapterListPane(
                        chapters: series.chapters,
                        selectedChapterID: $selectedChapterID,
                        title: series.title
                    )
                } else {
                    ReaderDetailView(
                        chapters: series.chapters,
                        selectedChapterID: $selectedChapterID
                    )
                }
            } else {
                ComicSelectionPlaceholder(
                    title: "Comic Not Found",
                    systemImage: "exclamationmark.triangle",
                    message: "This comic is no longer available in the library."
                )
            }
        }
        .task(id: seriesID) {
            seedSelectionIfNeeded()
            await readerViewModel.open(libraryStore.chapter(id: selectedChapterID))
        }
        .onChange(of: libraryStore.series) { _, _ in
            guard series != nil else {
                dismiss()
                return
            }
            validateSelection()
        }
        .onChange(of: selectedChapterID) { _, newValue in
            Task {
                await readerViewModel.open(libraryStore.chapter(id: newValue))
            }
        }
    }

    private var series: ComicSeries? {
        libraryStore.series.first(where: { $0.id == seriesID })
    }

    private func seedSelectionIfNeeded() {
        guard hasSeededSelection == false else { return }
        hasSeededSelection = true

        if let initialChapterID,
           libraryStore.chapters(in: seriesID).contains(where: { $0.id == initialChapterID }) {
            selectedChapterID = initialChapterID
            return
        }

        selectedChapterID = libraryStore.resumeChapter(in: seriesID)?.id
    }

    private func validateSelection() {
        let chapters = libraryStore.chapters(in: seriesID)
        if let selectedChapterID,
           chapters.contains(where: { $0.id == selectedChapterID }) {
            return
        }
        selectedChapterID = libraryStore.resumeChapter(in: seriesID)?.id
    }
}

private struct ComicSelectionPlaceholder: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
    }
}

private struct ChapterListPane: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let chapters: [ComicChapter]
    @Binding var selectedChapterID: UUID?
    let title: String

    @State private var chapterPendingDeletion: ComicChapter?

    var body: some View {
        List {
            if chapters.isEmpty {
                ContentUnavailableView(
                    "No Chapters",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("This comic does not have readable chapters yet.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(chapters) { chapter in
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
                                Text(chapter.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let storedProgress = libraryStore.storedProgress(for: chapter.id),
                                   let pageCount = chapter.pageCount {
                                    Text("Stopped at page \(min(storedProgress.pageIndex + 1, pageCount))/\(pageCount)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer(minLength: 0)

                            if selectedChapterID == chapter.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            chapterPendingDeletion = chapter
                        } label: {
                            Label("Delete Chapter", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
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
                Text("Delete \(chapterPendingDeletion.chapterTitle) from \(title).")
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
