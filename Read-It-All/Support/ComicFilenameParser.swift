import Foundation

enum ComicFilenameParser {
    struct ParsedResult {
        let seriesKey: String
        let seriesTitle: String
        let chapterTitle: String
        let issueNumber: Double?
    }

    static func parse(from url: URL) -> ParsedResult {
        let rawName = url.deletingPathExtension().lastPathComponent
        let cleanedName = normalize(rawName)
        let issueNumber = extractIssueNumber(from: cleanedName)

        let parentTitle = bestParentTitle(for: url)
        let seriesFromFilename = seriesTitleFromFilename(cleanedName, issueNumber: issueNumber)
        let preferredSeriesTitle = resolveSeriesTitle(
            cleanedName: cleanedName,
            seriesFromFilename: seriesFromFilename,
            parentTitle: parentTitle
        )

        let chapterTitle = makeChapterTitle(
            cleanedName: cleanedName,
            issueNumber: issueNumber,
            seriesTitle: preferredSeriesTitle
        )

        let key = normalizedKey(for: preferredSeriesTitle)

        return ParsedResult(
            seriesKey: key.isEmpty ? UUID().uuidString.lowercased() : key,
            seriesTitle: preferredSeriesTitle,
            chapterTitle: chapterTitle,
            issueNumber: issueNumber
        )
    }

    private static func resolveSeriesTitle(
        cleanedName: String,
        seriesFromFilename: String?,
        parentTitle: String?
    ) -> String {
        if let seriesFromFilename, isGenericContainerName(seriesFromFilename) == false {
            return seriesFromFilename
        }

        if let parentTitle, isLikelyStandaloneChapterName(cleanedName) {
            return parentTitle
        }

        if let parentTitle, isGenericContainerName(parentTitle) == false {
            return parentTitle
        }

        return cleanedName.isEmpty ? "Imported Comic" : cleanedName
    }

    private static func makeChapterTitle(
        cleanedName: String,
        issueNumber: Double?,
        seriesTitle: String
    ) -> String {
        let explicitChapterPattern = #"^(chapter|issue|book|part|volume|vol\.?|episode|ep\.?)\s+.*$"#
        if cleanedName.range(of: explicitChapterPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return cleanedName
        }

        if cleanedName.caseInsensitiveCompare(seriesTitle) != .orderedSame {
            return cleanedName
        }

        if let issueNumber {
            if issueNumber.rounded() == issueNumber {
                return "Issue \(Int(issueNumber))"
            }
            return "Issue \(issueNumber)"
        }

        return cleanedName.isEmpty ? "Untitled Chapter" : cleanedName
    }

    private static func seriesTitleFromFilename(_ cleanedName: String, issueNumber: Double?) -> String? {
        guard issueNumber != nil else {
            return isLikelyStandaloneChapterName(cleanedName) ? nil : cleanedName
        }

        let numericPattern = #"(.*?)(?:^|\s)(\d{1,4}(?:\.\d+)?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: numericPattern),
              let match = regex.firstMatch(in: cleanedName, range: NSRange(cleanedName.startIndex..., in: cleanedName)),
              let prefixRange = Range(match.range(at: 1), in: cleanedName) else {
            return isLikelyStandaloneChapterName(cleanedName) ? nil : cleanedName
        }

        let prefix = cleanedName[prefixRange].trimmingCharacters(in: .whitespacesAndNewlines)
        guard prefix.isEmpty == false else { return nil }
        return isLikelyStandaloneChapterName(prefix) ? nil : prefix
    }

    private static func bestParentTitle(for url: URL) -> String? {
        let directParent = normalize(url.deletingLastPathComponent().lastPathComponent)
        if directParent.isEmpty == false, isGenericContainerName(directParent) == false {
            return directParent
        }

        let grandParent = normalize(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent)
        if grandParent.isEmpty == false, isGenericContainerName(grandParent) == false {
            return grandParent
        }

        return nil
    }

    private static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\[[^\]]*\]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\([^\)]*\)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractIssueNumber(from value: String) -> Double? {
        let patterns = [
            #"(?:^|\s)(\d{1,4}(?:\.\d+)?)\s*$"#,
            #"(?:^|\s)(\d{1,4}(?:\.\d+)?)(?:\s+of\s+\d+)?(?:\s|$)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))
            guard let match = matches.last,
                  let range = Range(match.range(at: 1), in: value) else { continue }
            return Double(value[range])
        }

        return nil
    }

    private static func isLikelyStandaloneChapterName(_ value: String) -> Bool {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedValue.isEmpty == false else { return true }

        let patterns = [
            #"^\d{1,4}(?:\.\d+)?$"#,
            #"^(chapter|issue|book|part|volume|vol\.?|episode|ep\.?)\s*\d.*$"#,
            #"^(chapter|issue|book|part|volume|vol\.?|episode|ep\.?)\b.*$"#,
            #"^\d{1,4}(?:\.\d+)?\s+of\s+\d{1,4}$"#
        ]

        return patterns.contains {
            normalizedValue.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static func isGenericContainerName(_ value: String) -> Bool {
        let key = normalizedKey(for: value)
        let genericNames: Set<String> = [
            "",
            "books",
            "chapter",
            "chapters",
            "comics",
            "desktop",
            "documents",
            "downloads",
            "files",
            "imports",
            "library",
            "manga",
            "reader",
            "storage"
        ]

        return genericNames.contains(key) || isLikelyStandaloneChapterName(value)
    }

    private static func normalizedKey(for value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
