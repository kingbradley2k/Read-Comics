import SwiftUI
import UIKit

struct AsyncComicImageView: View {
    @Environment(\.colorScheme) private var colorScheme

    let source: ComicPageSource
    let maxPixelSize: CGFloat
    let fitMode: PageFitMode

    @State private var image: UIImage?
    @State private var errorMessage: String?
    @State private var imageOpacity = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(ReaderSurfaceStyle.pageColor(for: colorScheme))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(
                            width: fitMode == .fitWidth ? proxy.size.width : nil,
                            height: fitMode == .fitPage ? proxy.size.height : nil
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(imageOpacity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else if let errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .task(id: source.id + "::" + fitMode.rawValue) {
                await loadImage()
            }
        }
    }

    private func loadImage() async {
        do {
            if let cached = await ComicPageRenderer.shared.cachedImage(for: source, maxPixelSize: maxPixelSize) {
                image = cached
                errorMessage = nil
                imageOpacity = 1
                return
            }

            let rendered = try await ComicPageRenderer.shared.image(for: source, maxPixelSize: maxPixelSize)
            image = rendered
            errorMessage = nil
            imageOpacity = 0
            withAnimation(.easeOut(duration: 0.18)) {
                imageOpacity = 1
            }
        } catch {
            image = nil
            errorMessage = error.localizedDescription
            imageOpacity = 0
        }
    }
}

struct ChapterThumbnailView: View {
    @Environment(\.colorScheme) private var colorScheme

    let chapter: ComicChapter
    let documentURL: URL
    var preferredPageIndex: Int = 0
    var size: CGSize = CGSize(width: 46, height: 62)

    @State private var image: UIImage?
    @State private var imageOpacity = 0.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ReaderSurfaceStyle.pageColor(for: colorScheme))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(imageOpacity)
            } else {
                Image(systemName: "book.pages")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: "\(chapter.id)::\(preferredPageIndex)") {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        do {
            let document = try ComicDocumentFactory().openDocument(at: documentURL)
            let maxDimension = max(size.width, size.height) * UIScreen.main.scale
            let preferredSource = document.pages[safe: max(0, min(preferredPageIndex, document.pages.count - 1))]

            if let preferredSource,
               let cached = await ComicPageRenderer.shared.cachedImage(
                for: preferredSource,
                maxPixelSize: max(220, maxDimension)
               ) {
                image = cached
                imageOpacity = 1
                return
            }

            image = try await ComicPageRenderer.shared.thumbnail(
                for: document,
                maxPixelSize: max(220, maxDimension),
                preferredPageIndex: preferredPageIndex
            )
            imageOpacity = 0
            withAnimation(.easeOut(duration: 0.18)) {
                imageOpacity = 1
            }
        } catch {
            image = nil
            imageOpacity = 0
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
