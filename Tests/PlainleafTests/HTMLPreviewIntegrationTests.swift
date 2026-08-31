import AppKit
import WebKit
import XCTest
@testable import Plainleaf

@MainActor
final class HTMLPreviewIntegrationTests: XCTestCase {
    func testWebKitLoadsPaperDocumentAndProducesNonBlankSnapshot() async throws {
        try await verifyWebKitPreview(theme: .paper, artifactName: "HTMLPreview-Paper.png")
    }

    func testWebKitLoadsInkDocumentAndProducesNonBlankSnapshot() async throws {
        try await verifyWebKitPreview(theme: .ink, artifactName: "HTMLPreview-Ink.png")
    }

    func testWebKitRevealsAndTracksAHeadingSelectedFromTheOutline() async throws {
        let workspace = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let documentURL = workspace.appendingPathComponent("Outline.md")
        let paragraphs = String(repeating: "A paragraph that makes the document scroll.\n\n", count: 36)
        let source = "# Start\n\n\(paragraphs)## Target heading\n\n\(paragraphs)## Final section\n\nEnd."
        var renderer = HTMLDocumentRenderer(
            documentURL: documentURL,
            workspaceURL: workspace,
            theme: .paper
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 700),
            configuration: configuration
        )
        let observer = PreviewNavigationObserver()
        webView.navigationDelegate = observer
        let loaded = expectation(description: "WKWebView loads the outline fixture")
        observer.didFinish = { loaded.fulfill() }

        let window = NSWindow(
            contentRect: webView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.orderFront(nil)
        defer {
            webView.navigationDelegate = nil
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }

        webView.loadHTMLString(renderer.render(source), baseURL: nil)
        await fulfillment(of: [loaded], timeout: 8)
        let initialValue = try await webView.evaluateJavaScript(HTMLPreviewNavigation.scrollSnapshotScript)
        let initialSnapshot = try XCTUnwrap(HTMLPreviewScrollSnapshot(javascriptValue: initialValue))
        XCTAssertEqual(initialSnapshot.activeHeadingAnchor, "start")
        let script = try XCTUnwrap(
            HTMLPreviewNavigation.revealHeadingScript(anchor: "target-heading")
        )

        let before = try await webView.evaluateJavaScript("window.scrollY") as? Double ?? 0
        _ = try await webView.evaluateJavaScript(script)
        let after = try await webView.evaluateJavaScript("window.scrollY") as? Double ?? 0

        XCTAssertGreaterThan(after, before + 500)
        let targetTop = try await webView.evaluateJavaScript(
            "document.getElementById('target-heading').getBoundingClientRect().top"
        ) as? Double
        XCTAssertEqual(targetTop ?? -1, 24, accuracy: 2)
        let targetValue = try await webView.evaluateJavaScript(HTMLPreviewNavigation.scrollSnapshotScript)
        let targetSnapshot = try XCTUnwrap(HTMLPreviewScrollSnapshot(javascriptValue: targetValue))
        XCTAssertEqual(targetSnapshot.activeHeadingAnchor, "target-heading")

        _ = try await webView.evaluateJavaScript(
            "window.scrollTo(0, document.documentElement.scrollHeight)"
        )
        let finalValue = try await webView.evaluateJavaScript(HTMLPreviewNavigation.scrollSnapshotScript)
        let finalSnapshot = try XCTUnwrap(HTMLPreviewScrollSnapshot(javascriptValue: finalValue))
        XCTAssertEqual(finalSnapshot.activeHeadingAnchor, "final-section")
    }

    func testWebKitFootnoteReferenceAndBacklinkNavigateWithinDocument() async throws {
        let workspace = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let documentURL = workspace.appendingPathComponent("FootnoteNavigation.md")
        let paragraphs = String(repeating: "Body text that creates reading distance.\n\n", count: 32)
        let source = "# fn-note\n\nA claim[^note].\n\n\(paragraphs)[^note]: The local note."
        var renderer = HTMLDocumentRenderer(
            documentURL: documentURL,
            workspaceURL: workspace,
            theme: .paper
        )
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 900, height: 520),
            configuration: configuration
        )
        let observer = PreviewNavigationObserver()
        webView.navigationDelegate = observer
        let loaded = expectation(description: "WKWebView loads the footnote fixture")
        observer.didFinish = { loaded.fulfill() }

        let window = NSWindow(
            contentRect: webView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.orderFront(nil)
        defer {
            webView.navigationDelegate = nil
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }

        webView.loadHTMLString(renderer.render(source), baseURL: nil)
        await fulfillment(of: [loaded], timeout: 8)
        let initialY = try await webView.evaluateJavaScript("window.scrollY") as? Double ?? 0

        _ = try await webView.evaluateJavaScript("document.querySelector('[role=doc-noteref]').click()")
        try await Task.sleep(for: .milliseconds(100))
        let noteY = try await webView.evaluateJavaScript("window.scrollY") as? Double ?? 0
        let noteHash = try await webView.evaluateJavaScript("decodeURIComponent(window.location.hash)") as? String
        XCTAssertGreaterThan(noteY, initialY + 500)
        XCTAssertEqual(noteHash, "#plainleaf:fn:note")

        _ = try await webView.evaluateJavaScript("document.querySelector('.footnote-backref').click()")
        try await Task.sleep(for: .milliseconds(100))
        let returnY = try await webView.evaluateJavaScript("window.scrollY") as? Double ?? 0
        let returnHash = try await webView.evaluateJavaScript("decodeURIComponent(window.location.hash)") as? String
        XCTAssertLessThan(returnY, noteY - 500)
        XCTAssertEqual(returnHash, "#plainleaf:fnref:note:1")
    }

    private func verifyWebKitPreview(theme: PlainleafTheme, artifactName: String) async throws {
        let workspace = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/AcceptanceWorkspace", isDirectory: true)
        let documentURL = workspace.appendingPathComponent("Welcome.md")
        let source = try String(contentsOf: documentURL, encoding: .utf8)
        var renderer = HTMLDocumentRenderer(
            documentURL: documentURL,
            workspaceURL: workspace,
            theme: theme
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 980, height: 860), configuration: configuration)
        let observer = PreviewNavigationObserver()
        webView.navigationDelegate = observer

        let window = NSWindow(
            contentRect: webView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.orderFront(nil)
        defer {
            webView.navigationDelegate = nil
            window.orderOut(nil)
            window.contentView = nil
            window.close()
        }

        let loaded = expectation(description: "WKWebView loads generated Plainleaf HTML")
        observer.didFinish = { loaded.fulfill() }
        webView.loadHTMLString(renderer.render(source), baseURL: nil)
        await fulfillment(of: [loaded], timeout: 8)

        let domLength = try await webView.evaluateJavaScript("document.documentElement.outerHTML.length") as? Int
        XCTAssertGreaterThan(domLength ?? 0, 1_000)

        let image = try await snapshot(of: webView)
        let colors = sampledColors(in: image)
        XCTAssertGreaterThan(colors.count, 8, "The WebKit snapshot should contain rendered text and surfaces")

        if ProcessInfo.processInfo.environment["PLAINLEAF_SNAPSHOT"] == "1" {
            let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(".build/verification", isDirectory: true)
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let outputURL = outputDirectory.appendingPathComponent(artifactName)
            guard let tiff = image.tiffRepresentation,
                  let representation = NSBitmapImageRep(data: tiff),
                  let png = representation.representation(using: .png, properties: [:]) else {
                return XCTFail("Expected a PNG representation of the WebKit snapshot")
            }
            try png.write(to: outputURL, options: .atomic)
            print("Plainleaf HTML preview snapshot: \(outputURL.path)")
        }
    }

    private func snapshot(of webView: WKWebView) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: PreviewSnapshotError.missingImage)
                }
            }
        }
    }

    private func sampledColors(in image: NSImage) -> Set<UInt32> {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return [] }
        var colors: Set<UInt32> = []
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: 7) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 7) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let red = UInt32((color.redComponent * 255).rounded())
                let green = UInt32((color.greenComponent * 255).rounded())
                let blue = UInt32((color.blueComponent * 255).rounded())
                colors.insert((red << 16) | (green << 8) | blue)
            }
        }
        return colors
    }
}

@MainActor
private final class PreviewNavigationObserver: NSObject, WKNavigationDelegate {
    var didFinish: (() -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinish?()
    }
}

private enum PreviewSnapshotError: Error {
    case missingImage
}
