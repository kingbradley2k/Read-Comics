import Foundation

enum ComicFormat: String, Codable, CaseIterable, Hashable {
    case cbz
    case zip
    case cbr
    case rar
    case pdf
    case folder
    case image

    var displayName: String {
        switch self {
        case .cbz: return "CBZ"
        case .zip: return "ZIP"
        case .cbr: return "CBR"
        case .rar: return "RAR"
        case .pdf: return "PDF"
        case .folder: return "Folder"
        case .image: return "Image"
        }
    }
}

enum ReadingMode: String, CaseIterable, Identifiable {
    case paged
    case continuous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paged: return "Paged"
        case .continuous: return "Continuous"
        }
    }
}

enum ReadingDirection: String, CaseIterable, Identifiable {
    case leftToRight
    case rightToLeft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftToRight: return "Left to Right"
        case .rightToLeft: return "Right to Left"
        }
    }
}

enum PageFitMode: String, CaseIterable, Identifiable {
    case fitWidth
    case fitPage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fitWidth: return "Fit Width"
        case .fitPage: return "Fit Page"
        }
    }
}

struct ComicChapter: Codable, Identifiable, Hashable {
    let id: UUID
    let seriesKey: String
    let seriesTitle: String
    let chapterTitle: String
    let originalFilename: String
    let sourceRelativePath: String
    let format: ComicFormat
    let importedAt: Date
    let modifiedAt: Date
    let issueNumber: Double?
    let pageCount: Int?

    var issueLabel: String {
        guard let issueNumber else { return chapterTitle }
        if issueNumber.rounded() == issueNumber {
            return "#\(Int(issueNumber))"
        }
        return "#\(issueNumber)"
    }

    var subtitle: String {
        var parts: [String] = [format.displayName]
        if let pageCount {
            parts.append("\(pageCount) pages")
        }
        return parts.joined(separator: " • ")
    }
}

struct ComicProgress: Codable, Hashable {
    var pageIndex: Int
    var lastReadAt: Date

    init(pageIndex: Int = 0, lastReadAt: Date = .now) {
        self.pageIndex = pageIndex
        self.lastReadAt = lastReadAt
    }
}

struct PersistedLibrary: Codable {
    var chapters: [ComicChapter] = []
    var progressByChapterID: [String: ComicProgress] = [:]
}

struct ComicSeries: Identifiable, Hashable {
    let key: String
    let title: String
    let chapters: [ComicChapter]

    var id: String { key }
}
