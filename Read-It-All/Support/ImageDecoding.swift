import Foundation
import ImageIO
import PDFKit
import UIKit

enum ImageDecoding {
    nonisolated static func downsampledImage(from data: Data, maxPixelSize: CGFloat) throws -> UIImage {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            throw ComicDocumentError.imageDecodeFailed
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw ComicDocumentError.imageDecodeFailed
        }

        return UIImage(cgImage: cgImage)
    }

    nonisolated static func renderedPDFPage(from url: URL, pageIndex: Int, maxPixelSize: CGFloat) throws -> UIImage {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            throw ComicDocumentError.pdfLoadFailed
        }

        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else {
            throw ComicDocumentError.pdfLoadFailed
        }

        let scale = min(maxPixelSize / bounds.width, maxPixelSize / bounds.height)
        let renderSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: renderSize)

        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            UIColor.white.setFill()
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: renderSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
    }
}
