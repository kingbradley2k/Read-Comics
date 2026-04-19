import Foundation
import UIKit
import Unrar
import ZIPFoundation

actor ComicPageRenderer {
    static let shared = ComicPageRenderer()

    private let cache = NSCache<NSString, UIImage>()

    func cachedImage(for source: ComicPageSource, maxPixelSize: CGFloat = 2600) -> UIImage? {
        let cacheKey = "\(source.id)::\(Int(maxPixelSize))" as NSString
        return cache.object(forKey: cacheKey)
    }

    func image(for source: ComicPageSource, maxPixelSize: CGFloat = 2600) throws -> UIImage {
        let cacheKey = "\(source.id)::\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let image: UIImage
        switch source {
        case let .file(url):
            let data = try Data(contentsOf: url)
            image = try ImageDecoding.downsampledImage(from: data, maxPixelSize: maxPixelSize)
        case let .zipEntry(archiveURL, entryPath):
            let data = try dataForZipEntry(at: entryPath, archiveURL: archiveURL)
            image = try ImageDecoding.downsampledImage(from: data, maxPixelSize: maxPixelSize)
        case let .rarEntry(archiveURL, entryPath):
            let data = try dataForRarEntry(at: entryPath, archiveURL: archiveURL)
            image = try ImageDecoding.downsampledImage(from: data, maxPixelSize: maxPixelSize)
        case let .pdfPage(documentURL, pageIndex):
            image = try ImageDecoding.renderedPDFPage(from: documentURL, pageIndex: pageIndex, maxPixelSize: maxPixelSize)
        }

        cache.setObject(image, forKey: cacheKey)
        return image
    }

    func thumbnail(
        for document: LoadedComicDocument,
        maxPixelSize: CGFloat = 320,
        preferredPageIndex: Int = 0
    ) throws -> UIImage? {
        guard document.pages.isEmpty == false else { return nil }
        let pageIndex = min(max(preferredPageIndex, 0), document.pages.count - 1)
        return try image(for: document.pages[pageIndex], maxPixelSize: maxPixelSize)
    }

    func prefetchImages(for sources: [ComicPageSource], maxPixelSize: CGFloat = 2600) {
        for source in sources {
            _ = try? image(for: source, maxPixelSize: maxPixelSize)
        }
    }

    private func dataForZipEntry(at path: String, archiveURL: URL) throws -> Data {
        guard let archive = ZIPFoundation.Archive(url: archiveURL, accessMode: .read),
              let entry = archive[path] else {
            throw ComicDocumentError.missingArchiveEntry
        }

        var extracted = Data()
        _ = try archive.extract(entry, bufferSize: 64 * 1024, skipCRC32: false) { chunk in
            extracted.append(chunk)
        }
        return extracted
    }

    private func dataForRarEntry(at path: String, archiveURL: URL) throws -> Data {
        let archive = try Unrar.Archive(fileURL: archiveURL)
        guard let entry = try archive.entries().first(where: { $0.fileName == path }) else {
            throw ComicDocumentError.missingArchiveEntry
        }
        return try archive.extract(entry)
    }
}
