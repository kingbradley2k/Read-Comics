import SwiftUI
import UIKit

struct InteractiveComicPageView: View {
    @Environment(\.colorScheme) private var colorScheme

    let source: ComicPageSource
    let maxPixelSize: CGFloat
    let fitMode: PageFitMode
    let onLeadingTap: () -> Void
    let onCenterTap: () -> Void
    let onTrailingTap: () -> Void

    @State private var image: UIImage?
    @State private var errorMessage: String?
    @State private var imageOpacity = 0.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ReaderSurfaceStyle.pageColor(for: colorScheme))

            if let image {
                ZoomableComicImageView(
                    image: image,
                    backgroundColor: ReaderSurfaceStyle.pageUIColor(for: colorScheme),
                    fitMode: fitMode,
                    onLeadingTap: onLeadingTap,
                    onCenterTap: onCenterTap,
                    onTrailingTap: onTrailingTap
                )
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
        .task(id: source.id) {
            await loadImage()
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

private struct ZoomableComicImageView: UIViewRepresentable {
    let image: UIImage
    let backgroundColor: UIColor
    let fitMode: PageFitMode
    let onLeadingTap: () -> Void
    let onCenterTap: () -> Void
    let onTrailingTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLeadingTap: onLeadingTap,
            onCenterTap: onCenterTap,
            onTrailingTap: onTrailingTap
        )
    }

    func makeUIView(context: Context) -> ComicPageScrollView {
        let scrollView = ComicPageScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = backgroundColor
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.decelerationRate = .fast
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.onLayout = { [weak coordinator = context.coordinator] laidOutScrollView in
            coordinator?.layoutForCurrentBounds(in: laidOutScrollView)
        }

        let imageView = context.coordinator.imageView
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = backgroundColor
        scrollView.addSubview(imageView)

        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2

        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.require(toFail: doubleTapGesture)

        scrollView.addGestureRecognizer(singleTapGesture)
        scrollView.addGestureRecognizer(doubleTapGesture)

        return scrollView
    }

    func updateUIView(_ uiView: ComicPageScrollView, context: Context) {
        context.coordinator.onLeadingTap = onLeadingTap
        context.coordinator.onCenterTap = onCenterTap
        context.coordinator.onTrailingTap = onTrailingTap
        uiView.backgroundColor = backgroundColor
        context.coordinator.imageView.backgroundColor = backgroundColor
        context.coordinator.update(image: image, fitMode: fitMode, in: uiView)
    }

    final class ComicPageScrollView: UIScrollView {
        var onLayout: ((ComicPageScrollView) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onLayout?(self)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()

        var onLeadingTap: () -> Void
        var onCenterTap: () -> Void
        var onTrailingTap: () -> Void

        private var fitMode: PageFitMode = .fitWidth
        private var observedBoundsSize: CGSize = .zero

        init(
            onLeadingTap: @escaping () -> Void,
            onCenterTap: @escaping () -> Void,
            onTrailingTap: @escaping () -> Void
        ) {
            self.onLeadingTap = onLeadingTap
            self.onCenterTap = onCenterTap
            self.onTrailingTap = onTrailingTap
        }

        func update(image: UIImage, fitMode: PageFitMode, in scrollView: ComicPageScrollView) {
            let imageChanged = imageView.image !== image
            imageView.image = image

            let fitModeChanged = self.fitMode != fitMode
            self.fitMode = fitMode

            guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }
            observedBoundsSize = scrollView.bounds.size
            layoutImage(in: scrollView, resetZoom: imageChanged || fitModeChanged)
        }

        func layoutForCurrentBounds(in scrollView: ComicPageScrollView) {
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0 else { return }
            guard boundsSize != observedBoundsSize else { return }

            observedBoundsSize = boundsSize
            guard imageView.image != nil else { return }

            let shouldResetZoom = scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01
            layoutImage(in: scrollView, resetZoom: shouldResetZoom)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        @objc
        func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
            let location = recognizer.location(in: recognizer.view)
            let width = recognizer.view?.bounds.width ?? 1
            let normalizedX = location.x / width

            switch normalizedX {
            case ..<0.28:
                onLeadingTap()
            case 0.72...:
                onTrailingTap()
            default:
                onCenterTap()
            }
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let zoomScale = min(scrollView.maximumZoomScale, 2.5)
            let tapPoint = recognizer.location(in: imageView)
            let zoomSize = CGSize(
                width: scrollView.bounds.width / zoomScale,
                height: scrollView.bounds.height / zoomScale
            )
            let zoomOrigin = CGPoint(
                x: tapPoint.x - (zoomSize.width / 2),
                y: tapPoint.y - (zoomSize.height / 2)
            )

            scrollView.zoom(to: CGRect(origin: zoomOrigin, size: zoomSize), animated: true)
        }

        private func layoutImage(in scrollView: UIScrollView, resetZoom: Bool) {
            guard let image = imageView.image else { return }
            let availableSize = scrollView.bounds.size
            guard availableSize.width > 0, availableSize.height > 0 else { return }

            let displaySize = fittedSize(for: image.size, in: availableSize, fitMode: fitMode)
            imageView.frame = CGRect(origin: .zero, size: displaySize)
            scrollView.contentSize = displaySize

            if resetZoom {
                scrollView.zoomScale = scrollView.minimumZoomScale
                scrollView.contentOffset = .zero
            }

            centerImage(in: scrollView)
        }

        private func centerImage(in scrollView: UIScrollView) {
            let horizontalInset = max(0, (scrollView.bounds.width - imageView.frame.width) / 2)
            let verticalInset = max(0, (scrollView.bounds.height - imageView.frame.height) / 2)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        private func fittedSize(for imageSize: CGSize, in boundsSize: CGSize, fitMode: PageFitMode) -> CGSize {
            switch fitMode {
            case .fitWidth:
                let width = max(1, boundsSize.width)
                let height = max(1, width * imageSize.height / max(imageSize.width, 1))
                return CGSize(width: width, height: height)

            case .fitPage:
                let widthScale = boundsSize.width / max(imageSize.width, 1)
                let heightScale = boundsSize.height / max(imageSize.height, 1)
                let scale = max(0.01, min(widthScale, heightScale))
                return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            }
        }
    }
}
