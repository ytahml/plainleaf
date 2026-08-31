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

    func testParsesFootnotesByFirstReferenceWithMultilineDefinitions() {
        let source = """
        A detailed claim[^detail], another source[^source], and the detail again[^detail].

        [^source]: Source note.
        [^detail]: First **note**.
            Continued line.

            Second paragraph with `code`.
        """
        var renderer = MarkdownRenderer()

        let document = renderer.parse(source)

        guard case let .paragraph(runs) = document.blocks.first?.kind else {
            return XCTFail("Expected the body paragraph")
        }
        XCTAssertEqual(
            runs.compactMap(\.footnoteReference),
            [
                RenderedFootnoteReference(label: "detail", anchor: "detail", number: 1, occurrence: 1),
                RenderedFootnoteReference(label: "source", anchor: "source", number: 2, occurrence: 1),
                RenderedFootnoteReference(label: "detail", anchor: "detail", number: 1, occurrence: 2)
            ]
        )
        XCTAssertEqual(document.footnotes.map(\.label), ["detail", "source"])
        XCTAssertEqual(document.footnotes.map(\.referenceCount), [2, 1])
        XCTAssertEqual(document.footnotes[0].blocks.count, 2)
        guard case let .paragraph(firstDefinitionRuns) = document.footnotes[0].blocks[0].kind else {
            return XCTFail("Expected a parsed footnote paragraph")
        }
        XCTAssertTrue(firstDefinitionRuns.contains { $0.text == "note" && $0.style.contains(.strong) })
    }

    func testLeavesUndefinedAndCodeFootnoteSyntaxLiteral() {
        let source = """
        Undefined [^missing] and `[^code]` remain literal.

        ```md
        [^inside]: fenced code is not a definition
        ```
        """
        var renderer = MarkdownRenderer()

        let document = renderer.parse(source)

        XCTAssertTrue(document.footnotes.isEmpty)
        guard case let .paragraph(runs) = document.blocks[0].kind else {
            return XCTFail("Expected a paragraph")
        }
        XCTAssertEqual(runs.map(\.text).joined(), "Undefined [^missing] and [^code] remain literal.")
        XCTAssertTrue(runs.contains { $0.text == "[^code]" && $0.style.contains(.code) })
        guard case let .code(_, code) = document.blocks[1].kind else {
            return XCTFail("Expected fenced code")
        }
        XCTAssertTrue(code.contains("[^inside]: fenced code is not a definition"))
    }

    func testEscapedFootnoteReferenceStaysLiteral() {
        let source = """
        Escaped \\[^note] stays literal, while live [^note] becomes a reference.

        [^note]: The note.
        """
        var renderer = MarkdownRenderer()

        let document = renderer.parse(source)

        guard case let .paragraph(runs) = document.blocks[0].kind else {
            return XCTFail("Expected a paragraph")
        }
        XCTAssertEqual(runs.compactMap(\.footnoteReference).count, 1)
        XCTAssertTrue(runs.map(\.text).joined().contains("Escaped [^note] stays literal"))
        XCTAssertEqual(document.footnotes.count, 1)
    }

    func testExtractsOnlyRootLevelFootnoteDefinitionsOutsideLists() {
        let source = """
        - List item
          [^nested]: Nested list content must stay literal.

        Root claim[^root] and indented claim[^indented].

        [^root]: Root definition.
          [^indented]: Root definition with two leading spaces.
        """
        var renderer = MarkdownRenderer()

        let document = renderer.parse(source)

        XCTAssertEqual(document.footnotes.map(\.label), ["root", "indented"])
        guard case let .unorderedList(items) = document.blocks.first?.kind,
              case let .paragraph(listRuns) = items.first?.blocks.first?.kind else {
            return XCTFail("Expected the nested definition syntax to remain in the list")
        }
        XCTAssertTrue(listRuns.map(\.text).joined().contains("[^nested]: Nested list content"))
    }

    func testRootDefinitionAfterAListIsNotRejectedAsNested() {
        let source = """
        - List item

        Root claim[^root].

           [^root]: Root definition with three leading spaces.
        """
        var renderer = MarkdownRenderer()

        let document = renderer.parse(source)

        XCTAssertEqual(document.footnotes.map(\.label), ["root"])
        XCTAssertEqual(document.footnotes.first?.blocks.count, 1)
    }
}
