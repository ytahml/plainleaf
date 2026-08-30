import XCTest
@testable import Plainleaf

final class MarkdownRendererTests: XCTestCase {
    func testParsesGFMTableTaskAndStrikethrough() {
        let source = """
        - [x] shipped
        - [ ] verify

        | Name | State |
        | :--- | ---: |
        | Plainleaf | ~~draft~~ |
        """
        var renderer = MarkdownRenderer()

        let document = renderer.parse(source)

        guard case let .unorderedList(items) = document.blocks[0].kind else {
            return XCTFail("Expected a task list")
        }
        XCTAssertEqual(items.map(\.checkState), [.checked, .unchecked])

        guard case let .table(alignments, header, rows) = document.blocks[1].kind else {
            return XCTFail("Expected a GFM table")
        }
        XCTAssertEqual(alignments, [.left, .right])
        XCTAssertEqual(header.count, 2)
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows[0][1][0].style.contains(.strikethrough))
    }

    func testRawHTMLRemainsVisibleAsSource() {
        var renderer = MarkdownRenderer()
        let document = renderer.parse("<script>alert('no')</script>")

        guard case let .rawHTML(html) = document.blocks[0].kind else {
            return XCTFail("Expected raw HTML node")
        }
        XCTAssertEqual(html, "<script>alert('no')</script>\n")
    }

    func testImageSourceIsDataNotLoadedContent() {
        var renderer = MarkdownRenderer()
        let document = renderer.parse("![Remote](https://example.com/private.png)")

        guard case let .image(source, alt) = document.blocks[0].kind else {
            return XCTFail("Expected image node")
        }
        XCTAssertEqual(source, "https://example.com/private.png")
        XCTAssertEqual(alt, "Remote")
    }
}
