import Foundation

struct WorkspaceSearchFile: Equatable, Sendable {
    let url: URL
    let relativePath: String
}

struct WorkspaceSearchDocument: Equatable, Sendable {
    let file: WorkspaceSearchFile
    let contents: String
}

struct WorkspaceSearchOverride: Equatable, Sendable {
    let url: URL
    let contents: String
}

struct WorkspaceSearchMatch: Identifiable, Equatable, Sendable {
    let lineNumber: Int
    let excerpt: String

    var id: Int { lineNumber }
}

struct WorkspaceSearchResult: Identifiable, Equatable, Sendable {
    let file: WorkspaceSearchFile
    let pathMatched: Bool
    let occurrenceCount: Int
    let matches: [WorkspaceSearchMatch]

    var id: String { file.url.standardizedFileURL.path }
    var displayName: String { file.url.deletingPathExtension().lastPathComponent }
}

struct WorkspaceSearchResponse: Equatable, Sendable {
    let results: [WorkspaceSearchResult]
    let totalResultCount: Int
    let searchedFileCount: Int
    let unreadableFileCount: Int
}

enum WorkspaceSearchEngine {
    private static let comparisonOptions: String.CompareOptions = [
        .caseInsensitive,
        .diacriticInsensitive,
        .widthInsensitive
    ]

    static func search(
        query: String,
        documents: [WorkspaceSearchDocument],
        resultLimit: Int = 80,
        snippetsPerFile: Int = 3
    ) -> WorkspaceSearchResponse {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else {
            return WorkspaceSearchResponse(
                results: [],
                totalResultCount: 0,
                searchedFileCount: documents.count,
                unreadableFileCount: 0
            )
        }

        var results = documents.compactMap { document -> WorkspaceSearchResult? in
            guard !Task.isCancelled else { return nil }
            let pathMatched = contains(needle, in: document.file.relativePath)
            let occurrenceCount = countOccurrences(of: needle, in: document.contents)
            guard pathMatched || occurrenceCount > 0 else { return nil }

            let matches = matchingLines(
                query: needle,
                in: document.contents,
                limit: max(0, snippetsPerFile)
            )
            return WorkspaceSearchResult(
                file: document.file,
                pathMatched: pathMatched,
                occurrenceCount: occurrenceCount,
                matches: matches
            )
        }

        results.sort { lhs, rhs in
            if lhs.pathMatched != rhs.pathMatched { return lhs.pathMatched }
            if lhs.occurrenceCount != rhs.occurrenceCount {
                return lhs.occurrenceCount > rhs.occurrenceCount
            }
            return lhs.file.relativePath.localizedStandardCompare(rhs.file.relativePath) == .orderedAscending
        }

        return WorkspaceSearchResponse(
            results: Array(results.prefix(max(0, resultLimit))),
            totalResultCount: results.count,
            searchedFileCount: documents.count,
            unreadableFileCount: 0
        )
    }

    private static func contains(_ query: String, in value: String) -> Bool {
        value.range(of: query, options: comparisonOptions) != nil
    }

    private static func countOccurrences(of query: String, in value: String) -> Int {
        var count = 0
        var searchRange = value.startIndex..<value.endIndex
        while let match = value.range(of: query, options: comparisonOptions, range: searchRange) {
            if Task.isCancelled { break }
            count += 1
            guard match.upperBound < value.endIndex else { break }
            searchRange = match.upperBound..<value.endIndex
        }
        return count
    }

    private static func matchingLines(query: String, in contents: String, limit: Int) -> [WorkspaceSearchMatch] {
        guard limit > 0 else { return [] }
        let normalized = contents
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        var matches: [WorkspaceSearchMatch] = []
        matches.reserveCapacity(min(limit, 3))

        for (offset, line) in lines.enumerated() {
            if Task.isCancelled { break }
            let value = String(line)
            guard contains(query, in: value) else { continue }
            matches.append(WorkspaceSearchMatch(
                lineNumber: offset + 1,
                excerpt: excerpt(from: value, matching: query)
            ))
            if matches.count == limit { break }
        }
        return matches
    }

    private static func excerpt(from line: String, matching query: String) -> String {
        let clean = line
            .replacingOccurrences(of: "\t", with: "    ")
            .trimmingCharacters(in: .whitespaces)
        guard let match = clean.range(of: query, options: comparisonOptions) else {
            return String(clean.prefix(150))
        }

        let leadingCount = clean.distance(from: clean.startIndex, to: match.lowerBound)
        let trailingCount = clean.distance(from: match.upperBound, to: clean.endIndex)
        let start = clean.index(match.lowerBound, offsetBy: -min(leadingCount, 44))
        let end = clean.index(match.upperBound, offsetBy: min(trailingCount, 92))
        let prefix = start == clean.startIndex ? "" : "…"
        let suffix = end == clean.endIndex ? "" : "…"
        return prefix + String(clean[start..<end]) + suffix
    }
}

enum WorkspaceSearchService {
    static func search(
        query: String,
        files: [WorkspaceSearchFile],
        openDocumentOverride: WorkspaceSearchOverride?
    ) async throws -> WorkspaceSearchResponse {
        let task = Task.detached(priority: .userInitiated) {
            var documents: [WorkspaceSearchDocument] = []
            documents.reserveCapacity(files.count)
            var unreadableFileCount = 0

            for file in files {
                try Task.checkCancellation()
                let contents: String
                if let openDocumentOverride,
                   openDocumentOverride.url.standardizedFileURL == file.url.standardizedFileURL {
                    contents = openDocumentOverride.contents
                } else {
                    do {
                        contents = try String(contentsOf: file.url, encoding: .utf8)
                    } catch {
                        unreadableFileCount += 1
                        continue
                    }
                }
                documents.append(WorkspaceSearchDocument(file: file, contents: contents))
            }

            let response = WorkspaceSearchEngine.search(query: query, documents: documents)
            try Task.checkCancellation()
            return WorkspaceSearchResponse(
                results: response.results,
                totalResultCount: response.totalResultCount,
                searchedFileCount: response.searchedFileCount,
                unreadableFileCount: unreadableFileCount
            )
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
