import Foundation
import XCTest
@testable import Plainleaf

final class HTMLPreviewRenderCacheTests: XCTestCase {
    func testScrollUpdatesSkipRenderingAndContentInputsInvalidateCache() {
        var cache = HTMLPreviewRenderCache()
        let root = URL(fileURLWithPath: "/workspace")
        func input(_ source: String = "# First", file: String = "note.md",
                   workspace: URL? = nil, theme: PlainleafTheme = .paper,
                   appearance: ReadingAppearance = .standard) -> HTMLPreviewRenderInput {
            HTMLPreviewRenderInput(source: source, documentURL: root.appendingPathComponent(file),
                                   workspaceURL: workspace ?? root, theme: theme, appearance: appearance)
        }
        XCTAssertTrue(cache.updatedHTML(for: input())?.contains("First") == true)
        for _ in 0..<20 { XCTAssertNil(cache.updatedHTML(for: input())) }
        for changed in [input("# Edited"), input(file: "other.md"),
                        input(workspace: root.appendingPathComponent("nested")),
                        input(theme: .ink), input(appearance: .standard.adjustingTextSize(by: 1))] {
            cache = HTMLPreviewRenderCache()
            XCTAssertNotNil(cache.updatedHTML(for: input()))
            XCTAssertNotNil(cache.updatedHTML(for: changed))
            XCTAssertNil(cache.updatedHTML(for: changed))
        }
    }
}
