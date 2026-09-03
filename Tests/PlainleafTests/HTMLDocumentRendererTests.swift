import Foundation
import XCTest
@testable import Plainleaf

final class HTMLDocumentRendererTests: XCTestCase {
    func testProducesSemanticHTMLWithScriptAndNetworkBoundaries() {
        let workspace = URL(fileURLWithPath: "/tmp/plainleaf-html-tests", isDirectory: true)
        let document = workspace.appendingPathComponent("Notes.md")
        let source = """
        # Plainleaf

        <script>alert('no')</script>

        ![Remote](https://example.com/private.png)

        [Guide](Guide.md)
        """
        var renderer = HTMLDocumentRenderer(documentURL: document, workspaceURL: workspace, theme: .paper)

        let html = renderer.render(source)

        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("<h1 id=\"plainleaf\">Plainleaf</h1>"))
        XCTAssertTrue(html.contains("script-src 'none'"))
        XCTAssertTrue(html.contains("&lt;script&gt;alert(&#39;no&#39;)&lt;/script&gt;"))
        XCTAssertFalse(html.contains("<script>alert"))
        XCTAssertTrue(html.contains("Remote image blocked"))
        XCTAssertFalse(html.contains("src=\"https://"))
        XCTAssertTrue(html.contains("href=\"plainleaf://open?destination=Guide.md\""))
    }

    func testEmbedsOnlyImagesResolvedInsideWorkspace() throws {
        try withHTMLRendererTemporaryDirectory { root in
            let workspace = root.appendingPathComponent("Workspace", isDirectory: true)
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
            let document = workspace.appendingPathComponent("Notes.md")
            try Data("inside".utf8).write(to: workspace.appendingPathComponent("inside.png"))

            let outside = root.appendingPathComponent("outside.png")
            try Data("outside".utf8).write(to: outside)
            try FileManager.default.createSymbolicLink(
                at: workspace.appendingPathComponent("linked.png"),
                withDestinationURL: outside
            )

            var renderer = HTMLDocumentRenderer(documentURL: document, workspaceURL: workspace, theme: .paper)
            let html = renderer.render("![Inside](inside.png)\n\n![Outside](linked.png)")

            XCTAssertTrue(html.contains("data:image/png;base64,aW5zaWRl"))
            XCTAssertTrue(html.contains("Local image unavailable"))
            XCTAssertFalse(html.contains("b3V0c2lkZQ=="))
        }
    }

    func testCreatesStableUniqueHeadingAnchors() {
        let workspace = URL(fileURLWithPath: "/tmp/plainleaf-html-tests", isDirectory: true)
        var renderer = HTMLDocumentRenderer(
            documentURL: workspace.appendingPathComponent("Notes.md"),
            workspaceURL: workspace,
            theme: .ink
        )

        let html = renderer.render("# 重复标题\n\n## 重复标题\n\n[跳转](#重复标题)")

        XCTAssertTrue(html.contains("id=\"重复标题\""))
        XCTAssertTrue(html.contains("id=\"重复标题-2\""))
        XCTAssertTrue(html.contains("href=\"#重复标题\""))
        XCTAssertTrue(html.contains("color-scheme: dark"))
    }

    func testDoesNotEmbedSVGThatCouldReferenceExternalResources() throws {
        try withHTMLRendererTemporaryDirectory { workspace in
            let document = workspace.appendingPathComponent("Notes.md")
            try Data("<svg xmlns='http://www.w3.org/2000/svg'></svg>".utf8)
                .write(to: workspace.appendingPathComponent("diagram.svg"))
            var renderer = HTMLDocumentRenderer(documentURL: document, workspaceURL: workspace, theme: .paper)

            let html = renderer.render("![Diagram](diagram.svg)")

            XCTAssertTrue(html.contains("Local image unavailable"))
            XCTAssertFalse(html.contains("data:image/svg+xml"))
        }
    }

    func testRendersSemanticFootnotesWithRepeatedBacklinks() {
        let workspace = URL(fileURLWithPath: "/tmp/plainleaf-html-tests", isDirectory: true)
        var renderer = HTMLDocumentRenderer(
            documentURL: workspace.appendingPathComponent("Footnotes.md"),
            workspaceURL: workspace,
            theme: .paper
        )
        let source = """
        Evidence[^来源] can be cited twice[^来源], while undefined [^missing] stays visible.

        [^来源]: A **local** source with `code`.
        """

        let html = renderer.render(source)

        XCTAssertTrue(html.contains("role=\"doc-noteref\""))
        XCTAssertTrue(html.contains("role=\"doc-endnotes\""))
        XCTAssertTrue(html.contains("id=\"plainleaf:fnref:来源:1\""))
        XCTAssertTrue(html.contains("id=\"plainleaf:fnref:来源:2\""))
        XCTAssertTrue(html.contains("id=\"plainleaf:fn:来源\""))
        XCTAssertTrue(html.contains("href=\"#plainleaf:fn:来源\""))
        XCTAssertTrue(html.contains("href=\"#plainleaf:fnref:来源:2\""))
        XCTAssertTrue(html.contains("<strong>local</strong>"))
        XCTAssertTrue(html.contains("undefined [^missing] stays visible"))
        XCTAssertFalse(html.contains("[^来源]:"))
        XCTAssertTrue(html.contains("script-src 'none'"))
    }

    func testFootnoteIdentifiersCannotCollideWithHeadingsOrOtherReferences() {
        let workspace = URL(fileURLWithPath: "/tmp/plainleaf-html-tests", isDirectory: true)
        var renderer = HTMLDocumentRenderer(
            documentURL: workspace.appendingPathComponent("AnchorCollisions.md"),
            workspaceURL: workspace,
            theme: .paper
        )
        let source = """
        # fn-note

        ## fnref-note

        ## fnref-note-2

        First[^note], repeated[^note], and similarly named[^note-2].

        [^note]: Repeated note.
        [^note-2]: Similar label.
        """

        let html = renderer.render(source)
        let identifiers = html.matches(of: #/ id="([^"]+)"/#).map { String($0.1) }
        let fragmentTargets = html.matches(of: #/ href="#([^"]+)"/#).map { String($0.1) }

        XCTAssertTrue(html.contains("<h1 id=\"fn-note\">"))
        XCTAssertTrue(html.contains("<h2 id=\"fnref-note\">"))
        XCTAssertTrue(html.contains("<h2 id=\"fnref-note-2\">"))
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertTrue(fragmentTargets.allSatisfy(Set(identifiers).contains))
    }

    func testInjectsBoundedReadingAppearanceAsCSSVariables() {
        let workspace = URL(fileURLWithPath: "/tmp/plainleaf-html-tests", isDirectory: true)
        var renderer = HTMLDocumentRenderer(
            documentURL: workspace.appendingPathComponent("Typesetting.md"),
            workspaceURL: workspace,
            theme: .paper,
            appearance: ReadingAppearance(
                textSize: 20.5,
                leading: .open,
                measure: .wide
            )
        )

        let html = renderer.render("# Typesetting")

        XCTAssertTrue(html.contains("--body-size: 20.5px"))
        XCTAssertTrue(html.contains("--body-leading: 1.94"))
        XCTAssertTrue(html.contains("--paper-width: 940px"))
        XCTAssertTrue(html.contains("font-size: var(--body-size)"))
        XCTAssertTrue(html.contains("line-height: var(--body-leading)"))
        XCTAssertTrue(html.contains("width: min(100%, var(--paper-width))"))
        XCTAssertTrue(html.contains("font-family: \"LXGW WenKai GB Lite\""))
        XCTAssertTrue(html.contains("Fonts/LXGWWenKaiGBLite-Regular.ttf"))
        XCTAssertTrue(html.contains("font-src 'self' file:"))
        XCTAssertFalse(html.contains("body { font-size: 16.5px; }"))
    }

    func testStandaloneHTMLKeepsPortableLinksAndBlocksExecutableSchemes() throws {
        try withHTMLRendererTemporaryDirectory { workspace in
            let document = workspace.appendingPathComponent("Field Notes.md")
            try Data("image".utf8).write(to: workspace.appendingPathComponent("leaf.png"))
            var renderer = HTMLDocumentRenderer(
                documentURL: document,
                workspaceURL: workspace,
                theme: .paper,
                purpose: .standalone
            )
            let source = """
            # Export

            [Guide](Guides/Writing.md) [Section](#export) [Web](https://example.com/read?q=leaf)

            [Script](javascript:alert(1)) [Data](data:text/html,unsafe) [File](file:///tmp/private)

            ![Leaf](leaf.png)
            """

            let html = renderer.render(source)

            XCTAssertTrue(html.contains("<title>Field Notes</title>"))
            XCTAssertTrue(html.contains("data-plainleaf-purpose=\"standalone\""))
            XCTAssertTrue(html.contains("href=\"Guides/Writing.md\""))
            XCTAssertTrue(html.contains("href=\"#export\""))
            XCTAssertTrue(html.contains("href=\"https://example.com/read?q=leaf\""))
            XCTAssertTrue(html.contains("data:image/png;base64,aW1hZ2U="))
            XCTAssertEqual(html.components(separatedBy: "class=\"blocked-link\"").count - 1, 3)
            XCTAssertFalse(html.contains("plainleaf://"))
            XCTAssertFalse(html.contains("href=\"javascript:"))
            XCTAssertFalse(html.contains("href=\"data:"))
            XCTAssertFalse(html.contains("href=\"file:"))
            XCTAssertTrue(html.contains("script-src 'none'"))
            XCTAssertTrue(html.contains("connect-src 'none'"))
            XCTAssertTrue(html.contains("font-src 'none'"))
            XCTAssertFalse(html.contains("@font-face"))
        }
    }

    func testStandaloneExportWritesOneUTF8FileAndRendererResetsHeadingAnchors() throws {
        try withHTMLRendererTemporaryDirectory { workspace in
            let document = workspace.appendingPathComponent("你好.md")
            let destination = workspace.appendingPathComponent("exported.html")
            let export = StandaloneHTMLExport(
                source: "# 重复\n\n## 重复",
                documentURL: document,
                workspaceURL: workspace,
                theme: .ink,
                appearance: ReadingAppearance(textSize: 20.5, leading: .open, measure: .wide)
            )

            XCTAssertEqual(export.suggestedFilename, "你好.html")
            try export.write(to: destination)
            let html = try String(contentsOf: destination, encoding: .utf8)
            XCTAssertTrue(html.contains("<h1 id=\"重复\">"))
            XCTAssertTrue(html.contains("<h2 id=\"重复-2\">"))
            XCTAssertTrue(html.contains("--body-size: 20.5px"))
            XCTAssertTrue(html.contains("color-scheme: dark"))

            var renderer = HTMLDocumentRenderer(
                documentURL: document,
                workspaceURL: workspace,
                theme: .paper
            )
            let first = renderer.render("# Same")
            let second = renderer.render("# Same")
            XCTAssertTrue(first.contains("id=\"same\""))
            XCTAssertTrue(second.contains("id=\"same\""))
            XCTAssertFalse(second.contains("id=\"same-2\""))
        }
    }
}

private func withHTMLRendererTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlainleafHTMLTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}
