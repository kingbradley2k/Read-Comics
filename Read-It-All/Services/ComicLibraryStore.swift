import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ComicLibraryStore: ObservableObject {
    @Published private(set) var chapters: [ComicChapter] = []
    @Published private(set) var progressByChapterID: [UUID: ComicProgress] = [:]
    @Published var lastImportError: String?

    private let fileManager = FileManager.default
    private let factory = ComicDocumentFactory()
    private let importDirectoryURL: URL
    private let indexURL: URL

    init() {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storageRoot = appSupportURL.appendingPathComponent("ReadItAll", isDirectory: true)
        self.importDirectoryURL = storageRoot.appendingPathComponent("Imports", isDirectory: true)
        self.indexURL = storageRoot.appendingPathComponent("library.json")

        try? fileManager.createDirectory(at: importDirectoryURL, withIntermediateDirectories: true)
        loadLibrary()
    }

    var series: [ComicSeries] {
        Dictionary(grouping: chapters, by: \.seriesKey)
            .map { key, value in
                ComicSeries(key: key, title: value.first?.seriesTitle ?? key, chapters: sortChapters(value))
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func chapter(id: UUID?) -> ComicChapter? {
        guard let id else { return nil }
        return chapters.first(where: { $0.id == id })
    }

    func chapters(in seriesID: String?) -> [ComicChapter] {
        guard let seriesID else { return [] }
        return series.first(where: { $0.id == seriesID })?.chapters ?? []
    }

    func progress(for chapterID: UUID) -> ComicProgress {
        progressByChapterID[chapterID] ?? ComicProgress()
    }

    func storedProgress(for chapterID: UUID) -> ComicProgress? {
        progressByChapterID[chapterID]
    }

    func resumeState(in seriesID: String) -> (chapter: ComicChapter, progress: ComicProgress)? {
        chapters(in: seriesID)
            .compactMap { chapter in
                guard let progress = progressByChapterID[chapter.id] else { return nil }
                return (chapter, progress)
            }
            .max { lhs, rhs in
                lhs.progress.lastReadAt < rhs.progress.lastReadAt
            }
    }

    func resumeChapter(in seriesID: String) -> ComicChapter? {
        resumeState(in: seriesID)?.chapter
    }

    func latestReadDate(in seriesID: String) -> Date? {
        resumeState(in: seriesID)?.progress.lastReadAt
    }

    func latestImportDate(in seriesID: String) -> Date? {
        chapters(in: seriesID).map(\.importedAt).max()
    }

    func storageURL(for chapter: ComicChapter) -> URL {
        importDirectoryURL.appendingPathComponent(chapter.sourceRelativePath, isDirectory: chapter.format == .folder)
    }

    @discardableResult
    func importItems(from urls: [URL]) async -> [ComicChapter] {
        var imported: [ComicChapter] = []
        lastImportError = nil

        for url in urls {
            do {
                let chapter = try importItem(from: url)
                chapters.append(chapter)
                imported.append(chapter)
            } catch {
                lastImportError = error.localizedDescription
            }
        }

        chapters = sortChapters(chapters)
        saveLibrary()
        return imported
    }

    func updateProgress(chapterID: UUID, pageIndex: Int) {
        progressByChapterID[chapterID] = ComicProgress(pageIndex: max(0, pageIndex), lastReadAt: .now)
        saveLibrary()
    }

    func deleteChapter(_ chapter: ComicChapter) {
        lastImportError = nil

        do {
            try removeStoredItemIfNeeded(at: storageURL(for: chapter))
            chapters.removeAll { $0.id == chapter.id }
            progressByChapterID.removeValue(forKey: chapter.id)
            chapters = sortChapters(chapters)
            saveLibrary()
        } catch {
            lastImportError = "\"\(chapter.chapterTitle)\" could not be deleted."
        }
    }

    func deleteSeries(_ series: ComicSeries) {
        lastImportError = nil

        do {
            try removeSeriesStorageIfNeeded(for: series)
            let chapterIDs = Set(series.chapters.map(\.id))
            chapters.removeAll { chapterIDs.contains($0.id) }
            progressByChapterID = progressByChapterID.filter { chapterIDs.contains($0.key) == false }
            chapters = sortChapters(chapters)
            saveLibrary()
        } catch {
            lastImportError = "\"\(series.title)\" could not be deleted."
        }
    }

    private func importItem(from url: URL) throws -> ComicChapter {
        let accessStarted = url.startAccessingSecurityScopedResource()
        defer {
            if accessStarted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard UTType.comicFormat(for: url) != nil else {
            throw ComicDocumentError.unsupportedFormat
        }

        let parsed = ComicFilenameParser.parse(from: url)
        let destinationURL = try copyImportedItem(from: url, parsed: parsed)
        let inspection = try factory.inspect(at: destinationURL)
        let attributes = try fileManager.attributesOfItem(atPath: destinationURL.path)
        let modifiedAt = (attributes[.modificationDate] as? Date) ?? .now

        return ComicChapter(
            id: UUID(),
            seriesKey: parsed.seriesKey,
            seriesTitle: parsed.seriesTitle,
            chapterTitle: parsed.chapterTitle,
            originalFilename: url.lastPathComponent,
            sourceRelativePath: relativeImportPath(for: destinationURL),
            format: inspection.format,
            importedAt: .now,
            modifiedAt: modifiedAt,
            issueNumber: parsed.issueNumber,
            pageCount: inspection.pageCount
        )
    }

    private func copyImportedItem(from url: URL, parsed: ComicFilenameParser.ParsedResult) throws -> URL {
        let seriesDirectoryURL = importDirectoryURL.appendingPathComponent(parsed.seriesKey, isDirectory: true)
        try fileManager.createDirectory(at: seriesDirectoryURL, withIntermediateDirectories: true)

        let sanitizedFilename = url.lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let preferredName = sanitizedFilename.isEmpty ? UUID().uuidString : sanitizedFilename
        let destinationURL = uniqueImportURL(
            in: seriesDirectoryURL,
            preferredName: preferredName,
            isDirectory: url.hasDirectoryPath
        )

        try fileManager.copyItem(at: url, to: destinationURL)
        return destinationURL
    }

    private func relativeImportPath(for url: URL) -> String {
        let rootPath = importDirectoryURL.standardizedFileURL.path
        let destinationPath = url.standardizedFileURL.path
        guard destinationPath.hasPrefix(rootPath) else {
            return url.lastPathComponent
        }

        let prefixLength = rootPath.hasSuffix("/") ? rootPath.count : rootPath.count + 1
        return String(destinationPath.dropFirst(prefixLength))
    }

    private func uniqueImportURL(in directoryURL: URL, preferredName: String, isDirectory: Bool) -> URL {
        let nameURL = URL(fileURLWithPath: preferredName)
        let baseName = nameURL.deletingPathExtension().lastPathComponent
        let pathExtension = nameURL.pathExtension

        var candidateIndex = 1
        var candidateURL = directoryURL.appendingPathComponent(preferredName, isDirectory: isDirectory)

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateIndex += 1
            let numberedName: String
            if pathExtension.isEmpty {
                numberedName = "\(baseName) \(candidateIndex)"
            } else {
                numberedName = "\(baseName) \(candidateIndex).\(pathExtension)"
            }
            candidateURL = directoryURL.appendingPathComponent(numberedName, isDirectory: isDirectory)
        }

        return candidateURL
    }

    private func removeSeriesStorageIfNeeded(for series: ComicSeries) throws {
        let seriesDirectoryURL = importDirectoryURL.appendingPathComponent(series.id, isDirectory: true)
        if fileManager.fileExists(atPath: seriesDirectoryURL.path) {
            try fileManager.removeItem(at: seriesDirectoryURL)
            return
        }

        for chapter in series.chapters {
            try removeStoredItemIfNeeded(at: storageURL(for: chapter))
        }
    }

    private func removeStoredItemIfNeeded(at url: URL) throws {
        guard isWithinImportDirectory(url) else { return }

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }

        try pruneEmptyImportDirectories(startingAt: url.deletingLastPathComponent())
    }

    private func pruneEmptyImportDirectories(startingAt directoryURL: URL) throws {
        let rootURL = importDirectoryURL.standardizedFileURL
        var currentURL = directoryURL.standardizedFileURL

        while currentURL.path.hasPrefix(rootURL.path), currentURL != rootURL {
            let contents = try fileManager.contentsOfDirectory(
                at: currentURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            guard contents.isEmpty else { break }

            try fileManager.removeItem(at: currentURL)
            currentURL.deleteLastPathComponent()
        }
    }

    private func isWithinImportDirectory(_ url: URL) -> Bool {
        let rootPath = importDirectoryURL.standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        return targetPath == rootPath || targetPath.hasPrefix(rootPath + "/")
    }

    private func loadLibrary() {
        guard let data = try? Data(contentsOf: indexURL) else { return }

        do {
            let persisted = try JSONDecoder().decode(PersistedLibrary.self, from: data)
            self.chapters = sortChapters(persisted.chapters)
            self.progressByChapterID = Dictionary(
                uniqueKeysWithValues: persisted.progressByChapterID.compactMap { key, value in
                    guard let uuid = UUID(uuidString: key) else { return nil }
                    return (uuid, value)
                }
            )
        } catch {
            lastImportError = "Saved library could not be loaded."
        }
    }

    private func saveLibrary() {
        let persisted = PersistedLibrary(
            chapters: chapters,
            progressByChapterID: Dictionary(
                uniqueKeysWithValues: progressByChapterID.map { key, value in
                    (key.uuidString, value)
                }
            )
        )

        do {
            try fileManager.createDirectory(at: indexURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder.prettyPrinted.encode(persisted)
            try data.write(to: indexURL, options: [.atomic])
        } catch {
            lastImportError = "Library changes could not be saved."
        }
    }

    private func sortChapters(_ chapters: [ComicChapter]) -> [ComicChapter] {
        chapters.sorted { lhs, rhs in
            if lhs.seriesTitle != rhs.seriesTitle {
                return lhs.seriesTitle.localizedCaseInsensitiveCompare(rhs.seriesTitle) == .orderedAscending
            }
            switch (lhs.issueNumber, rhs.issueNumber) {
            case let (l?, r?) where l != r:
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.chapterTitle.localizedStandardCompare(rhs.chapterTitle) == .orderedAscending
            }
        }
    }
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
