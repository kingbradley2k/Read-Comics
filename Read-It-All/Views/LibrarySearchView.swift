import SwiftUI

struct LibrarySearchView: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if trimmedQuery.isEmpty {
                    ContentUnavailableView(
                        "Search Library",
                        systemImage: "magnifyingglass",
                        description: Text("Search comics and chapters from your library.")
                    )
                } else if filteredSeries.isEmpty && filteredChapters.isEmpty {
                    ContentUnavailableView.search(text: trimmedQuery)
                } else {
                    List {
                        if filteredSeries.isEmpty == false {
                            Section("Comics") {
                                ForEach(filteredSeries) { series in
                                    NavigationLink {
                                        SeriesReaderScreen(seriesID: series.id)
                                    } label: {
                                        SearchSeriesRow(series: series)
                                    }
                                }
                            }
                        }

                        if filteredChapters.isEmpty == false {
                            Section("Chapters") {
                                ForEach(filteredChapters) { chapter in
                                    NavigationLink {
                                        SeriesReaderScreen(
                                            seriesID: chapter.seriesKey,
                                            initialChapterID: chapter.id
                                        )
                                    } label: {
                                        SearchChapterRow(chapter: chapter)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Comics or chapters")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedQuery: String {
        trimmedQuery.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private var filteredSeries: [ComicSeries] {
        guard normalizedQuery.isEmpty == false else { return [] }
        return libraryStore.series.filter { series in
            searchableText(for: series).contains(normalizedQuery)
        }
    }

    private var filteredChapters: [ComicChapter] {
        guard normalizedQuery.isEmpty == false else { return [] }
        return libraryStore.chapters.filter { chapter in
            searchableText(for: chapter).contains(normalizedQuery)
        }
    }

    private func searchableText(for series: ComicSeries) -> String {
        [
            series.title,
            series.chapters.first?.chapterTitle ?? "",
            series.chapters.first?.originalFilename ?? ""
        ]
        .joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func searchableText(for chapter: ComicChapter) -> String {
        [
            chapter.seriesTitle,
            chapter.chapterTitle,
            chapter.originalFilename,
            chapter.issueLabel
        ]
        .joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private struct SearchSeriesRow: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let series: ComicSeries

    var body: some View {
        HStack(spacing: 12) {
            if let representativeChapter {
                ChapterThumbnailView(
                    chapter: representativeChapter,
                    documentURL: libraryStore.storageURL(for: representativeChapter),
                    preferredPageIndex: preferredPageIndex,
                    size: CGSize(width: 52, height: 72)
                )
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemFill))
                    .frame(width: 52, height: 72)
                    .overlay {
                        Image(systemName: "book.pages")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(series.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let representativeChapter {
                    Text("Open \(representativeChapter.chapterTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("\(series.chapters.count) chapter\(series.chapters.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var representativeChapter: ComicChapter? {
        libraryStore.resumeChapter(in: series.id) ?? series.chapters.first
    }

    private var preferredPageIndex: Int {
        guard let representativeChapter else { return 0 }
        return libraryStore.storedProgress(for: representativeChapter.id)?.pageIndex ?? 0
    }
}

private struct SearchChapterRow: View {
    @EnvironmentObject private var libraryStore: ComicLibraryStore

    let chapter: ComicChapter

    var body: some View {
        HStack(spacing: 12) {
            ChapterThumbnailView(
                chapter: chapter,
                documentURL: libraryStore.storageURL(for: chapter),
                preferredPageIndex: libraryStore.storedProgress(for: chapter.id)?.pageIndex ?? 0,
                size: CGSize(width: 52, height: 72)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.chapterTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(chapter.seriesTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(chapter.subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
