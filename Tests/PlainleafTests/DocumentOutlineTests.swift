import XCTest
@testable import Plainleaf

final class DocumentOutlineTests: XCTestCase {
    func testBuildsHierarchicalOutlineWithStableDuplicateAnchors() {
        let source = """
        # Overview

        ## First steps

        ### 中文标题

        ## First steps
        """

        let outline = DocumentOutline.build(from: source)

        XCTAssertEqual(
            outline,
            [
                DocumentOutlineItem(title: "Overview", level: 1, anchor: "overview"),
                DocumentOutlineItem(title: "First steps", level: 2, anchor: "first-steps"),
                DocumentOutlineItem(title: "中文标题", level: 3, anchor: "中文标题"),
                DocumentOutlineItem(title: "First steps", level: 2, anchor: "first-steps-2")
            ]
        )
    }

    func testIncludesHeadingsRenderedInsideContainersInDocumentOrder() {
        let source = """
        > ## Quoted section

        - ### Listed section

        #### Final section
        """

        XCTAssertEqual(
            DocumentOutline.build(from: source).map(\.title),
            ["Quoted section", "Listed section", "Final section"]
        )
    }

    func testHTMLHeadingIdentifiersMatchOutlineAnchors() {
        let source = """
        # Repeat
        ## Repeat
        # !
        """
        let documentURL = URL(fileURLWithPath: "/tmp/Plainleaf/Note.md")
        let workspaceURL = documentURL.deletingLastPathComponent()
        var renderer = HTMLDocumentRenderer(
            documentURL: documentURL,
            workspaceURL: workspaceURL,
            theme: .paper
        )

        let html = renderer.render(source)
        let anchors = DocumentOutline.build(from: source).map(\.anchor)

        XCTAssertEqual(anchors, ["repeat", "repeat-2", "section"])
        for anchor in anchors {
            XCTAssertTrue(html.contains("id=\"\(anchor)\""))
        }
    }

    func testRevealHeadingScriptUsesAJSONEncodedAnchor() throws {
        let anchor = "heading\"); alert('blocked') //"
        let prefix = "document.getElementById("
        let suffix = ")?.scrollIntoView({block: 'start'});"
        let script = try XCTUnwrap(HTMLPreviewNavigation.revealHeadingScript(anchor: anchor))
        XCTAssertTrue(script.hasPrefix(prefix))
        XCTAssertTrue(script.hasSuffix(suffix))

        let encoded = String(script.dropFirst(prefix.count).dropLast(suffix.count))
        let decoded = try JSONSerialization.jsonObject(
            with: Data(encoded.utf8),
            options: .fragmentsAllowed
        ) as? String
        XCTAssertEqual(decoded, anchor)
        XCTAssertNil(HTMLPreviewNavigation.revealHeadingScript(anchor: ""))
    }

    func testPreviewScrollSnapshotParsesAnchorAndClampsProgress() throws {
        let snapshot = try XCTUnwrap(HTMLPreviewScrollSnapshot(javascriptValue: [
            "progress": 1.4,
            "anchor": "current-section"
        ]))

        XCTAssertEqual(snapshot.progress, 1)
        XCTAssertEqual(snapshot.activeHeadingAnchor, "current-section")
        let emptyAnchor = try XCTUnwrap(HTMLPreviewScrollSnapshot(
            javascriptValue: ["progress": -0.2, "anchor": NSNull()]
        ))
        XCTAssertEqual(emptyAnchor.progress, 0)
        XCTAssertNil(emptyAnchor.activeHeadingAnchor)
        XCTAssertNil(HTMLPreviewScrollSnapshot(javascriptValue: ["anchor": "missing-progress"]))
    }

    func testLocalFragmentNavigationAcceptsWebKitEncodingAndEscapesTheAnchor() throws {
        XCTAssertEqual(
            HTMLPreviewNavigation.localFragmentAnchor(from: try XCTUnwrap(URL(string: "about:blank#fn-note"))),
            "fn-note"
        )
        XCTAssertEqual(
            HTMLPreviewNavigation.localFragmentAnchor(from: try XCTUnwrap(URL(string: "about:blank%23fn-%E4%B8%AD%E6%96%87"))),
            "fn-中文"
        )
        XCTAssertNil(HTMLPreviewNavigation.localFragmentAnchor(
            from: try XCTUnwrap(URL(string: "https://example.com/#fn-note"))
        ))

        let anchor = "note\"); alert('blocked') //"
        let script = try XCTUnwrap(HTMLPreviewNavigation.revealLocalFragmentScript(anchor: anchor))
        XCTAssertFalse(script.contains("const anchor = \(anchor);"))
        XCTAssertTrue(script.contains("\\\""))
        XCTAssertTrue(script.contains("target.focus"))
    }
}
