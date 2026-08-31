import Foundation

struct SourceRevealRequest: Identifiable, Equatable {
    let id: UUID
    let documentURL: URL
    let query: String
    let lineNumber: Int

    init(documentURL: URL, query: String, lineNumber: Int) {
        self.id = UUID()
        self.documentURL = documentURL
        self.query = query
        self.lineNumber = lineNumber
    }
}

enum SourceRevealLocator {
    private static let comparisonOptions: NSString.CompareOptions = [
        .caseInsensitive,
        .diacriticInsensitive,
        .widthInsensitive
    ]

    static func range(in text: String, query: String, lineNumber: Int) -> NSRange? {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        let source = text as NSString
        guard source.length > 0 else { return nil }

        if lineNumber > 0, let lineRange = rangeOfLine(lineNumber, in: source) {
            let match = source.range(of: needle, options: comparisonOptions, range: lineRange)
            if match.location != NSNotFound { return match }
        }

        let fallback = source.range(
            of: needle,
            options: comparisonOptions,
            range: NSRange(location: 0, length: source.length)
        )
        return fallback.location == NSNotFound ? nil : fallback
    }

    private static func rangeOfLine(_ lineNumber: Int, in source: NSString) -> NSRange? {
        var currentLine = 1
        var location = 0
        while location < source.length {
            let range = source.lineRange(for: NSRange(location: location, length: 0))
            if currentLine == lineNumber { return range }
            currentLine += 1
            let nextLocation = NSMaxRange(range)
            guard nextLocation > location else { break }
            location = nextLocation
        }
        return nil
    }
}
