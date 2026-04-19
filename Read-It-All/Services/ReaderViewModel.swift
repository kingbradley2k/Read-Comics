import Combine
import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published private(set) var chapter: ComicChapter?
    @Published private(set) var document: LoadedComicDocument?
    @Published var currentPageIndex: Int = 0 {
        didSet {
            guard oldValue != currentPageIndex,
                  let chapter else { return }
            libraryStore.updateProgress(chapterID: chapter.id, pageIndex: currentPageIndex)
        }
    }
    @Published var readingMode: ReadingMode = .paged
    @Published var readingDirection: ReadingDirection = .leftToRight
    @Published var fitMode: PageFitMode = .fitWidth
    @Published var showsPageStrip = true
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let libraryStore: ComicLibraryStore
    private let factory = ComicDocumentFactory()

    init(libraryStore: ComicLibraryStore) {
        self.libraryStore = libraryStore
    }

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    func open(_ chapter: ComicChapter?) async {
        guard let chapter else {
            self.chapter = nil
            self.document = nil
            self.currentPageIndex = 0
            self.errorMessage = nil
            return
        }

        if self.chapter?.id == chapter.id, document != nil {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let url = libraryStore.storageURL(for: chapter)
            let document = try factory.openDocument(at: url)
            self.chapter = chapter
            self.document = document
            self.currentPageIndex = min(max(0, libraryStore.progress(for: chapter.id).pageIndex), max(0, document.pageCount - 1))
            libraryStore.updateProgress(chapterID: chapter.id, pageIndex: currentPageIndex)
        } catch {
            self.chapter = chapter
            self.document = nil
            self.currentPageIndex = 0
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updateCurrentPageIndex(_ index: Int) {
        guard pageCount > 0 else { return }
        currentPageIndex = min(max(index, 0), pageCount - 1)
    }

    func advancePage() {
        guard pageCount > 0 else { return }
        updateCurrentPageIndex(currentPageIndex + 1)
    }

    func rewindPage() {
        guard pageCount > 0 else { return }
        updateCurrentPageIndex(currentPageIndex - 1)
    }
}
