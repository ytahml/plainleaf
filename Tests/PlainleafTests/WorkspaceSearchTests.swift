import Foundation
import XCTest
@testable import Plainleaf

final class WorkspaceSearchTests: XCTestCase {
    func testSearchRanksPathMatchesAndFindsUnicodeContent() {
        let documents = [
            document(
                path: "Guides/Café.md",
                contents: "Introduction\nA café is a quiet place."
            ),
            document(
                path: "Notes/Other.md",
                contents: "cafe cafe\nNothing else"
            ),
            document(
                path: "Notes/Chinese.md",
                contents: "素页让 Markdown 保持纯粹。"
            )
        ]

        let response = WorkspaceSearchEngine.search(query: "CAFE", documents: documents)

        XCTAssertEqual(response.totalResultCount, 2)
        XCTAssertEqual(response.results.map(\.file.relativePath), ["Guides/Café.md", "Notes/Other.md"])
        XCTAssertTrue(response.results[0].pathMatched)
        XCTAssertEqual(response.results[0].matches, [
            WorkspaceSearchMatch(lineNumber: 2, excerpt: "A café is a quiet place.")
        ])
        XCTAssertEqual(response.results[1].occurrenceCount, 2)

        let chinese = WorkspaceSearchEngine.search(query: "markdown", documents: documents)
        XCTAssertEqual(chinese.results.map(\.file.relativePath), ["Notes/Chinese.md"])
    }

    func testSearchCountsEveryOccurrenceButCapsLineSnippets() {
        let document = document(
            path: "Many.md",
            contents: "needle one\nneedle two\nneedle three\nneedle four"
        )

        let response = WorkspaceSearchEngine.search(
            query: "needle",
            documents: [document],
            snippetsPerFile: 2
        )

        XCTAssertEqual(response.results[0].occurrenceCount, 4)
        XCTAssertEqual(response.results[0].matches.map(\.lineNumber), [1, 2])
    }

    func testSearchResultLimitReportsTheUntruncatedTotal() {
        let documents = (1...5).map { index in
            document(path: "Note-\(index).md", contents: "shared phrase")
        }

        let response = WorkspaceSearchEngine.search(
            query: "shared",
            documents: documents,
            resultLimit: 2
        )

        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.totalResultCount, 5)
        XCTAssertEqual(response.searchedFileCount, 5)
    }

    func testAsyncSearchUsesOpenDocumentTextAndReportsUnreadableFiles() async throws {
        let workspace = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/AcceptanceWorkspace", isDirectory: true)
        let welcome = workspace.appendingPathComponent("Welcome.md")
        let missing = workspace.appendingPathComponent("Missing.md")
        let files = [
            WorkspaceSearchFile(url: welcome, relativePath: "Welcome.md"),
            WorkspaceSearchFile(url: missing, relativePath: "Missing.md")
        ]

        let response = try await WorkspaceSearchService.search(
            query: "unsaved needle",
            files: files,
            openDocumentOverride: WorkspaceSearchOverride(
                url: welcome,
                contents: "An unsaved needle is still searchable."
            )
        )

        XCTAssertEqual(response.results.map(\.file.relativePath), ["Welcome.md"])
        XCTAssertEqual(response.searchedFileCount, 1)
        XCTAssertEqual(response.unreadableFileCount, 1)
    }

    func testSourceRevealLocatorUsesTheRequestedLineThenFallsBackSafely() {
        let source = "first needle\nsecond\nthird NEEDLE"

        XCTAssertEqual(
            SourceRevealLocator.range(in: source, query: "needle", lineNumber: 3),
            NSRange(location: 26, length: 6)
        )
        XCTAssertEqual(
            SourceRevealLocator.range(in: source, query: "needle", lineNumber: 99),
            NSRange(location: 6, length: 6)
        )
        XCTAssertNil(SourceRevealLocator.range(in: source, query: "missing", lineNumber: 1))
    }

    private func document(path: String, contents: String) -> WorkspaceSearchDocument {
        WorkspaceSearchDocument(
            file: WorkspaceSearchFile(
                url: URL(fileURLWithPath: "/workspace/\(path)"),
                relativePath: path
            ),
            contents: contents
        )
    }
}
