import Foundation
import PDFKit
import Unrar
import UniformTypeIdentifiers
import ZIPFoundation

enum ComicDocumentError: LocalizedError {
    case unsupportedFormat
    case emptyDocument
    case imageDecodeFailed
    case pdfLoadFailed
    case missingArchiveEntry
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This file type is not supported by the current build."
        case .emptyDocument:
            return "No readable comic pages were found in this item."
        case .imageDecodeFailed:
            return "A page image could not be decoded."
        case .pdfLoadFailed:
            return "The PDF could not be opened."
        case .missingArchiveEntry:
            return "A comic page could not be found inside the archive."
        case let .importFailed(message):
            return message
        }
    }
}

enum ComicPageSource: Hashable, Identifiable {
    case file(URL)
    case zipEntry(archiveURL: URL, entryPath: String)
    case rarEntry(archiveURL: URL, entryPath: String)
    case pdfPage(documentURL: URL, pageIndex: Int)

    nonisolated var id: String {
        switch self {
        case let .file(url):
            return "file::\(url.path)"
        case let .zipEntry(archiveURL, entryPath):
            return "zip::\(archiveURL.path)::\(entryPath)"
        case let .rarEntry(archiveURL, entryPath):
            return "rar::\(archiveURL.path)::\(entryPath)"
        case let .pdfPage(documentURL, pageIndex):
            return "pdf::\(documentURL.path)::\(pageIndex)"
        }
    }

    nonisolated var shortLabel: String {
        switch self {
        case let .file(url):
            return url.lastPathComponent
        case let .zipEntry(_, entryPath), let .rarEntry(_, entryPath):
            return URL(fileURLWithPath: entryPath).lastPathComponent
        case let .pdfPage(_, pageIndex):
            return "Page \(pageIndex + 1)"
        }
    }
}

struct LoadedComicDocument {
    let sourceURL: URL
    let format: ComicFormat
    let pages: [ComicPageSource]

    var pageCount: Int { pages.count }
}

struct ComicInspection {
    let format: ComicFormat
    let pageCount: Int
}

struct ComicDocumentFactory {
    private let fileManager = FileManager.default

    func inspect(at url: URL) throws -> ComicInspection {
        let document = try openDocument(at: url)
        return ComicInspection(format: document.format, pageCount: document.pageCount)
    }

    func openDocument(at url: URL) throws -> LoadedComicDocument {
        guard let format = UTType.comicFormat(for: url) else {
            throw ComicDocumentError.unsupportedFormat
        }

        let pages: [ComicPageSource]
        switch format {
        case .cbz, .zip:
            pages = try loadZipPages(from: url)
        case .cbr, .rar:
            pages = try loadRarPages(from: url)
        case .pdf:
            pages = try loadPDFPages(from: url)
        case .folder:
            pages = try loadFolderPages(from: url)
        case .image:
            pages = [.file(url)]
        }

        guard pages.isEmpty == false else {
            throw ComicDocumentError.emptyDocument
        }

        return LoadedComicDocument(sourceURL: url, format: format, pages: pages)
    }

    private func loadZipPages(from url: URL) throws -> [ComicPageSource] {
        guard let archive = ZIPFoundation.Archive(url: url, accessMode: .read) else {
            throw ComicDocumentError.emptyDocument
        }

        let pagePaths = archive
            .filter { $0.type == .file && Self.isImagePath($0.path) }
            .map(\.path)
            .sorted(by: Self.naturalSort)

        return pagePaths.map { ComicPageSource.zipEntry(archiveURL: url, entryPath: $0) }
    }

    private func loadRarPages(from url: URL) throws -> [ComicPageSource] {
        let archive = try Unrar.Archive(fileURL: url)
        let pagePaths = try archive.entries()
            .filter { $0.directory == false && Self.isImagePath($0.fileName) }
            .map(\.fileName)
            .sorted(by: Self.naturalSort)

        return pagePaths.map { ComicPageSource.rarEntry(archiveURL: url, entryPath: $0) }
    }

    private func loadPDFPages(from url: URL) throws -> [ComicPageSource] {
        guard let document = PDFDocument(url: url) else {
            throw ComicDocumentError.pdfLoadFailed
        }

        return (0..<document.pageCount).map { ComicPageSource.pdfPage(documentURL: url, pageIndex: $0) }
    }

    private func loadFolderPages(from url: URL) throws -> [ComicPageSource] {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw ComicDocumentError.emptyDocument
        }

        let pages = enumerator.compactMap { item -> ComicPageSource? in
            guard let fileURL = item as? URL else { return nil }
            return Self.isImagePath(fileURL.path) ? .file(fileURL) : nil
        }
        .sorted { lhs, rhs in
            Self.naturalSort(lhs.id, rhs.id)
        }

        return pages
    }

    nonisolated static func isImagePath(_ path: String) -> Bool {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "heic", "heif", "gif", "bmp", "tif", "tiff"].contains(ext)
    }

    nonisolated static func naturalSort(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}
