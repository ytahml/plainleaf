import AppKit
import Foundation
import Highlighter
import UniformTypeIdentifiers

enum HTMLRenderPurpose: Equatable {
    case preview
    case standalone
}

struct HTMLDocumentRenderer {
    private let documentURL: URL
    private let workspaceURL: URL
    private let theme: PlainleafTheme
    private let appearance: ReadingAppearance
    private let purpose: HTMLRenderPurpose
    private var headingIdentifiers = HeadingIdentifierGenerator()

    init(
        documentURL: URL,
        workspaceURL: URL,
        theme: PlainleafTheme,
        appearance: ReadingAppearance = .standard,
        purpose: HTMLRenderPurpose = .preview
    ) {
        self.documentURL = documentURL
        self.workspaceURL = workspaceURL
        self.theme = theme
        self.appearance = appearance
        self.purpose = purpose
    }

    mutating func render(_ source: String) -> String {
        headingIdentifiers = HeadingIdentifierGenerator()
        var markdownRenderer = MarkdownRenderer()
        let document = markdownRenderer.parse(source)
        let content = renderBlocks(document.blocks)
        let footnotes = renderFootnotes(document.footnotes)

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="generator" content="Plainleaf">
          <meta name="referrer" content="no-referrer">
          <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; font-src \(purpose == .preview ? "'self' file:" : "'none'"); script-src 'none'; connect-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'">
          <title>\(escape(documentTitle))</title>
          <style>\(styleSheet)</style>
        </head>
        <body data-plainleaf-purpose="\(purpose == .preview ? "preview" : "standalone")">
          <main class="reading-canvas">
            <article class="paper" aria-label="Rendered Markdown document">
              \(content)
              \(footnotes)
            </article>
          </main>
        </body>
        </html>
        """
    }

    private mutating func renderBlocks(_ blocks: [RenderedBlock]) -> String {
        var rendered: [String] = []
        rendered.reserveCapacity(blocks.count)
        for block in blocks {
            rendered.append(renderBlock(block))
        }
        return rendered.joined(separator: "\n")
    }

    private mutating func renderBlock(_ block: RenderedBlock) -> String {
        switch block.kind {
        case let .heading(level, runs):
            let safeLevel = min(max(level, 1), 6)
            let identifier = headingIdentifiers.identifier(for: runs.map(\.text).joined())
            return "<h\(safeLevel) id=\"\(escape(identifier))\">\(renderRuns(runs))</h\(safeLevel)>"
        case let .paragraph(runs):
            return "<p>\(renderRuns(runs))</p>"
        case let .image(source, alt):
            return renderImage(source: source, alt: alt)
        case let .code(language, source):
            return renderCode(language: language, source: source)
        case let .blockQuote(children):
            return "<blockquote>\(renderBlocks(children))</blockquote>"
        case let .unorderedList(items):
            return "<ul>\(renderListItems(items))</ul>"
        case let .orderedList(start, items):
            return "<ol start=\"\(start)\">\(renderListItems(items))</ol>"
        case let .table(alignments, header, rows):
            return renderTable(alignments: alignments, header: header, rows: rows)
        case .thematicBreak:
            return "<hr>"
        case let .rawHTML(html):
            return """
            <aside class="raw-html" aria-label="Raw HTML shown as text">
              <div class="raw-html-label">&lt;/&gt; Raw HTML shown as text</div>
              <pre>\(escape(html))</pre>
            </aside>
            """
        }
    }

    private mutating func renderListItems(_ items: [RenderedListItem]) -> String {
        var rendered: [String] = []
        rendered.reserveCapacity(items.count)
        for item in items {
            rendered.append(renderListItem(item))
        }
        return rendered.joined(separator: "\n")
    }

    private mutating func renderListItem(_ item: RenderedListItem) -> String {
        let contents = renderBlocks(item.blocks)
        switch item.checkState {
        case .checked?:
            return "<li class=\"task checked\"><span class=\"task-marker\" role=\"img\" aria-label=\"Completed task\">✓</span><div>\(contents)</div></li>"
        case .unchecked?:
            return "<li class=\"task\"><span class=\"task-marker\" role=\"img\" aria-label=\"Incomplete task\"></span><div>\(contents)</div></li>"
        case nil:
            return "<li>\(contents)</li>"
        }
    }

    private func renderTable(
        alignments: [TableAlignment?],
        header: [[InlineRun]],
        rows: [[[InlineRun]]]
    ) -> String {
        let headingCells = header.enumerated().map { column, runs in
            "<th\(alignmentAttribute(for: column, in: alignments))>\(renderRuns(runs))</th>"
        }.joined()
        let bodyRows = rows.map { row in
            let cells = header.indices.map { column in
                let runs = column < row.count ? row[column] : []
                return "<td\(alignmentAttribute(for: column, in: alignments))>\(renderRuns(runs))</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        return """
        <div class="table-scroll" role="region" aria-label="Markdown table" tabindex="0">
          <table><thead><tr>\(headingCells)</tr></thead><tbody>\(bodyRows)</tbody></table>
        </div>
        """
    }

    private func alignmentAttribute(for column: Int, in alignments: [TableAlignment?]) -> String {
        guard column < alignments.count else { return "" }
        switch alignments[column] {
        case .center?: return " class=\"align-center\""
        case .right?: return " class=\"align-right\""
        default: return ""
        }
    }

    private func renderRuns(_ runs: [InlineRun]) -> String {
        var html = ""
        var index = 0
        while index < runs.count {
            let destination = runs[index].destination
            var end = index + 1
            while end < runs.count, runs[end].destination == destination {
                end += 1
            }

            let contents = runs[index..<end].map(renderRun).joined()
            if let destination {
                if let link = linkURL(for: destination) {
                    let privacyAttribute = purpose == .standalone ? " referrerpolicy=\"no-referrer\"" : ""
                    html += "<a href=\"\(escape(link))\"\(privacyAttribute)>\(contents)</a>"
                } else {
                    html += "<span class=\"blocked-link\" title=\"Unsupported link blocked by Plainleaf\">\(contents)</span>"
                }
            } else {
                html += contents
            }
            index = end
        }
        return html
    }

    private func renderRun(_ run: InlineRun) -> String {
        if let reference = run.footnoteReference {
            let referenceID = HTMLFootnoteIdentifier.reference(
                anchor: reference.anchor,
                occurrence: reference.occurrence
            )
            let endnoteID = HTMLFootnoteIdentifier.endnote(anchor: reference.anchor)
            return "<sup class=\"footnote-ref\" id=\"\(escape(referenceID))\"><a href=\"#\(escape(endnoteID))\" role=\"doc-noteref\" aria-label=\"Footnote \(reference.number)\">\(reference.number)</a></sup>"
        }
        var html = escape(run.text).replacingOccurrences(of: "\n", with: "<br>")
        if run.style.contains(.rawHTML) {
            html = "<code class=\"raw-inline\">\(html)</code>"
        } else if run.style.contains(.code) {
            html = "<code>\(html)</code>"
        }
        if run.style.contains(.strikethrough) { html = "<del>\(html)</del>" }
        if run.style.contains(.emphasis) { html = "<em>\(html)</em>" }
        if run.style.contains(.strong) { html = "<strong>\(html)</strong>" }
        return html
    }

    private mutating func renderFootnotes(_ footnotes: [RenderedFootnote]) -> String {
        guard !footnotes.isEmpty else { return "" }
        let items = footnotes.map { footnote in
            let backlinks = (1...footnote.referenceCount).map { occurrence in
                let referenceID = HTMLFootnoteIdentifier.reference(
                    anchor: footnote.anchor,
                    occurrence: occurrence
                )
                let suffix = footnote.referenceCount > 1 ? " \(occurrence)" : ""
                return "<a class=\"footnote-backref\" href=\"#\(escape(referenceID))\" aria-label=\"Back to footnote reference \(occurrence)\">↩︎\(suffix)</a>"
            }.joined(separator: " ")
            let endnoteID = HTMLFootnoteIdentifier.endnote(anchor: footnote.anchor)
            return """
            <li id="\(escape(endnoteID))" role="doc-endnote">
              <div class="footnote-body">\(renderBlocks(footnote.blocks))</div>
              <span class="footnote-backlinks">\(backlinks)</span>
            </li>
            """
        }.joined(separator: "\n")
        return """
        <section class="footnotes" role="doc-endnotes" aria-label="Footnotes">
          <h2 class="footnotes-title">Notes</h2>
          <ol>\(items)</ol>
        </section>
        """
    }

    private func renderImage(source: String?, alt: String) -> String {
        switch imageData(for: source) {
        case let .available(dataURL):
            let caption = alt.isEmpty ? "" : "<figcaption>\(escape(alt))</figcaption>"
            let accessibilityText = alt.isEmpty ? "Local image" : alt
            return "<figure><img src=\"\(dataURL)\" alt=\"\(escape(accessibilityText))\">\(caption)</figure>"
        case .remote:
            return imagePlaceholder(title: "Remote image blocked", detail: alt.isEmpty ? (source ?? "Missing image source") : alt)
        case .unavailable:
            return imagePlaceholder(title: "Local image unavailable", detail: alt.isEmpty ? (source ?? "Missing image source") : alt)
        }
    }

    private func imagePlaceholder(title: String, detail: String) -> String {
        """
        <aside class="image-placeholder" role="img" aria-label="\(escape(title)): \(escape(detail))">
          <span class="image-placeholder-mark" aria-hidden="true">▧</span>
          <span><strong>\(escape(title))</strong><small>\(escape(detail))</small></span>
        </aside>
        """
    }

    private enum ImageData {
        case available(String)
        case remote
        case unavailable
    }

    private func imageData(for source: String?) -> ImageData {
        guard let source, !source.isEmpty else { return .unavailable }

        let candidate: URL
        if let parsed = URL(string: source), let scheme = parsed.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" { return .remote }
            guard scheme == "file", parsed.isFileURL else { return .unavailable }
            candidate = parsed
        } else {
            let decoded = source.removingPercentEncoding ?? source
            candidate = documentURL.deletingLastPathComponent().appendingPathComponent(decoded)
        }

        let resolvedWorkspace = workspaceURL.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedCandidate = candidate.standardizedFileURL.resolvingSymlinksInPath()
        guard resolvedCandidate.isDescendant(of: resolvedWorkspace),
              FileManager.default.fileExists(atPath: resolvedCandidate.path),
              let type = UTType(filenameExtension: resolvedCandidate.pathExtension),
              type.conforms(to: .image),
              let mimeType = type.preferredMIMEType,
              mimeType != "image/svg+xml",
              let data = try? Data(contentsOf: resolvedCandidate) else {
            return .unavailable
        }

        return .available("data:\(mimeType);base64,\(data.base64EncodedString())")
    }

    private func renderCode(language: String?, source: String) -> String {
        let normalized = normalize(language)
        let highlighted = highlightedHTML(source: source, language: normalized) ?? escape(source)
        let label = language?.isEmpty == false ? language!.uppercased() : "CODE"
        let languageClass = normalized.map { " class=\"language-\(escape($0))\"" } ?? ""
        return """
        <section class="code-block">
          <div class="code-label">\(escape(label))</div>
          <pre><code\(languageClass)>\(highlighted)</code></pre>
        </section>
        """
    }

    private func highlightedHTML(source: String, language: String?) -> String? {
        guard let highlighter = Highlighter() else { return nil }
        _ = highlighter.setTheme(
            theme.isDark ? "flexoki-dark" : "flexoki-light",
            withFont: "SFMono-Regular",
            ofSize: 13.5
        )
        guard let value = highlighter.highlight(source, as: language) ?? highlighter.highlight(source) else {
            return nil
        }

        var html = ""
        let range = NSRange(location: 0, length: value.length)
        value.enumerateAttributes(in: range) { attributes, subrange, _ in
            let text = escape(value.attributedSubstring(from: subrange).string)
            guard let color = attributes[.foregroundColor] as? NSColor else {
                html += text
                return
            }
            html += "<span style=\"color:\(cssColor(color))\">\(text)</span>"
        }
        return html
    }

    private func normalize(_ language: String?) -> String? {
        guard let value = language?.lowercased(), !value.isEmpty else { return nil }
        let normalized = [
            "js": "javascript",
            "ts": "typescript",
            "py": "python",
            "sh": "bash",
            "zsh": "bash",
            "shell": "bash",
            "objc": "objectivec"
        ][value] ?? value
        let safe = normalized.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return safe.isEmpty ? nil : safe
    }

    private func linkURL(for destination: String) -> String? {
        if destination.hasPrefix("#") { return destination }
        if purpose == .standalone {
            return standaloneLinkURL(for: destination)
        }
        var components = URLComponents()
        components.scheme = "plainleaf"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "destination", value: destination)]
        return components.string ?? "#"
    }

    private func standaloneLinkURL(for destination: String) -> String? {
        let value = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !value.hasPrefix("//"),
              !value.hasPrefix("/") else {
            return nil
        }

        if let components = URLComponents(string: value),
           let scheme = components.scheme?.lowercased() {
            guard ["http", "https", "mailto"].contains(scheme) else { return nil }
            return components.string
        }
        return value
    }

    private var documentTitle: String {
        let title = documentURL.deletingPathExtension().lastPathComponent
        return title.isEmpty ? "Plainleaf Document" : title
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func cssColor(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#202124" }
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }

    private var styleSheet: String {
        """
        \(previewFontFaceRule)
        :root {
          color-scheme: \(theme.isDark ? "dark" : "light");
          --canvas: \(cssColor(theme.canvas));
          --surface: \(cssColor(theme.surface));
          --text: \(cssColor(theme.text));
          --muted: \(cssColor(theme.secondaryText));
          --accent: \(cssColor(theme.accent));
          --warm: \(cssColor(theme.warmAccent));
          --border: \(cssColor(theme.border));
          --code: \(cssColor(theme.codeBackground));
          --selection: \(cssColor(theme.selection));
          --body-size: \(cssNumber(appearance.textSize))px;
          --body-leading: \(cssNumber(appearance.leading.lineHeight));
          --paper-width: \(cssNumber(appearance.measure.maximumWidth))px;
          --reader: "LXGW WenKai GB Lite", ui-serif, "New York", "Songti SC", "STSongti-SC-Regular", Georgia, serif;
          --utility: -apple-system, BlinkMacSystemFont, "PingFang SC", sans-serif;
          --mono: ui-monospace, "SF Mono", SFMono-Regular, Menlo, monospace;
        }
        * { box-sizing: border-box; }
        html { min-height: 100%; background: var(--canvas); }
        body {
          min-height: 100vh;
          margin: 0;
          color: var(--text);
          background: var(--canvas);
          font-family: var(--reader);
          font-size: var(--body-size);
          line-height: var(--body-leading);
          -webkit-font-smoothing: antialiased;
          text-rendering: optimizeLegibility;
        }
        ::selection { color: var(--text); background: var(--selection); }
        .reading-canvas { width: 100%; padding: 16px 20px 64px; }
        .paper {
          width: min(100%, var(--paper-width));
          min-height: calc(100vh - 32px);
          margin: 0 auto;
          padding: 64px 72px 80px;
          background: var(--surface);
          border: 1px solid color-mix(in srgb, var(--border) 72%, transparent);
          border-radius: 16px;
          box-shadow: 0 8px 30px \(theme.isDark ? "rgba(0,0,0,.24)" : "rgba(32,33,36,.06)");
          overflow-wrap: break-word;
        }
        h1, h2, h3, h4, h5, h6 {
          margin: 1.65em 0 .55em;
          color: var(--text);
          font-family: var(--reader);
          font-weight: 650;
          line-height: 1.22;
          text-wrap: balance;
          scroll-margin-top: 24px;
        }
        h1:first-child, h2:first-child, h3:first-child { margin-top: 0; }
        h1 {
          margin-top: .15em;
          padding: .08em 0 .12em;
          font-size: 2.03rem;
          letter-spacing: -.022em;
        }
        h2 { font-size: 1.52rem; letter-spacing: -.014em; }
        h3 { font-size: 1.24rem; }
        h4 { font-size: 1.08rem; }
        h5 { font-size: 1rem; }
        h6 { color: var(--muted); font-size: .94rem; font-family: var(--utility); }
        p { margin: 0 0 1.12em; }
        strong { font-weight: 680; }
        a {
          color: var(--accent);
          text-decoration-line: underline;
          text-decoration-thickness: .07em;
          text-underline-offset: .18em;
        }
        a:hover { text-decoration-thickness: .12em; }
        a:focus-visible, [tabindex]:focus-visible { outline: 2px solid var(--accent); outline-offset: 4px; }
        .blocked-link {
          color: var(--muted);
          text-decoration-line: underline;
          text-decoration-style: dotted;
          text-underline-offset: .18em;
          cursor: not-allowed;
        }
        blockquote {
          margin: 1.5em 0;
          padding: .85em 1.05em .9em 1.25em;
          border-left: 3px solid var(--warm);
          border-radius: 0 10px 10px 0;
          background: color-mix(in srgb, var(--warm) 7%, transparent);
        }
        blockquote > :last-child { margin-bottom: 0; }
        ul, ol { margin: .55em 0 1.25em; padding-left: 1.55em; }
        li { margin: .34em 0; padding-left: .24em; }
        li::marker { color: var(--muted); font-family: var(--utility); font-size: .88em; }
        li > p { margin: 0; }
        li.task {
          display: grid;
          grid-template-columns: 1.15em minmax(0, 1fr);
          gap: .52em;
          padding-left: 0;
          list-style: none;
        }
        .task-marker {
          display: inline-grid;
          width: 1.05em;
          height: 1.05em;
          margin-top: .37em;
          place-items: center;
          border: 1.5px solid var(--muted);
          border-radius: 5px;
          color: var(--surface);
          font: 700 .72em/1 var(--utility);
        }
        .task.checked .task-marker { border-color: var(--accent); background: var(--accent); }
        code, pre { font-family: var(--mono); }
        :not(pre) > code {
          padding: .12em .36em .16em;
          border: 1px solid color-mix(in srgb, var(--border) 74%, transparent);
          border-radius: 6px;
          color: var(--accent);
          background: var(--code);
          font-size: .86em;
        }
        .code-block {
          margin: 1.55em 0;
          overflow: hidden;
          border: 1px solid color-mix(in srgb, var(--border) 78%, transparent);
          border-radius: 12px;
          background: var(--code);
        }
        .code-label {
          padding: 11px 16px 4px;
          color: var(--muted);
          font: 650 9px/1.4 var(--mono);
          letter-spacing: .11em;
        }
        .code-block pre {
          margin: 0;
          padding: 8px 16px 17px;
          overflow-x: auto;
          color: var(--text);
          font-size: 13.5px;
          line-height: 1.62;
          tab-size: 4;
        }
        .code-block code { white-space: pre; }
        .table-scroll {
          margin: 1.55em 0;
          overflow-x: auto;
          border: 1px solid var(--border);
          border-radius: 12px;
        }
        table { width: 100%; border-collapse: collapse; font-family: var(--utility); font-size: .84em; line-height: 1.5; }
        th, td { min-width: 128px; padding: .68em .85em; border-bottom: 1px solid var(--border); text-align: left; vertical-align: top; }
        th { background: var(--selection); font-weight: 650; }
        tbody tr:last-child td { border-bottom: 0; }
        tbody tr:hover td { background: color-mix(in srgb, var(--selection) 45%, transparent); }
        .align-center { text-align: center; }
        .align-right { text-align: right; }
        hr { margin: 2.1em 0; border: 0; border-top: 1px solid var(--border); }
        figure { margin: 1.7em 0; }
        figure img { display: block; max-width: 100%; max-height: 560px; margin: 0 auto; border-radius: 12px; }
        figcaption { margin-top: .65em; color: var(--muted); font: .76em/1.5 var(--utility); text-align: center; }
        .image-placeholder {
          display: flex;
          gap: .75em;
          align-items: center;
          margin: 1.35em 0;
          padding: .8em .9em;
          border: 1px solid color-mix(in srgb, var(--border) 75%, transparent);
          border-radius: 10px;
          background: var(--code);
          font: .84em/1.4 var(--utility);
        }
        .image-placeholder-mark { color: var(--muted); font-size: 1.25em; }
        .image-placeholder small { display: block; margin-top: .15em; color: var(--muted); }
        .raw-html {
          margin: 1.45em 0;
          padding: .75em .85em .85em;
          border: 1px solid color-mix(in srgb, var(--border) 75%, transparent);
          border-radius: 10px;
          background: var(--code);
        }
        .raw-html-label { color: var(--muted); font: 600 11px/1.4 var(--utility); }
        .raw-html pre { margin: .55em 0 0; overflow-x: auto; white-space: pre-wrap; font-size: 13px; line-height: 1.55; }
        .raw-inline { color: var(--muted) !important; }
        .footnote-ref {
          margin-left: .08em;
          font: 650 .7em/1 var(--utility);
          vertical-align: super;
        }
        .footnote-ref a {
          display: inline-block;
          min-width: 1.15em;
          padding: .1em .22em;
          border-radius: 6px;
          text-align: center;
          text-decoration: none;
        }
        .footnote-ref:target a,
        .footnotes li:target {
          background: color-mix(in srgb, var(--accent) 11%, transparent);
        }
        .footnotes {
          margin-top: 3.25em;
          padding-top: 1.35em;
          border-top: 1px solid var(--border);
          color: var(--muted);
          font-size: .86em;
          line-height: 1.62;
        }
        .footnotes-title {
          margin: 0 0 .9em;
          color: var(--muted);
          font: 650 10px/1.4 var(--mono);
          letter-spacing: .13em;
          text-transform: uppercase;
        }
        .footnotes ol { margin: 0; padding-left: 1.45em; }
        .footnotes li {
          margin: .75em 0;
          padding: .25em .35em .35em;
          border-radius: 8px;
          scroll-margin-top: 24px;
        }
        .footnotes li::marker { color: var(--accent); font-weight: 650; }
        .footnote-body { color: var(--text); }
        .footnote-body > :last-child { margin-bottom: .3em; }
        .footnote-backlinks { display: inline-flex; flex-wrap: wrap; gap: .45em; }
        .footnote-backref {
          color: var(--muted);
          font: 600 .78em/1.4 var(--utility);
          text-decoration: none;
        }
        .footnote-backref:hover { color: var(--accent); }
        @media (max-width: 720px) {
          .reading-canvas { padding: 0; }
          .paper { min-height: 100vh; padding: 38px 28px 60px; border: 0; border-radius: 0; box-shadow: none; }
          h1 { font-size: 1.78rem; }
        }
        @media (prefers-reduced-motion: no-preference) {
          a { transition: color 120ms ease, text-decoration-thickness 120ms ease; }
        }
        @media print {
          @page { margin: 18mm 17mm 20mm; }
          html, body { background: white; }
          body { color: #202124; font-size: 11pt; }
          .reading-canvas { padding: 0; }
          .paper { width: auto; min-height: 0; padding: 0; border: 0; box-shadow: none; }
          .code-block, blockquote, figure, table, .footnotes li { break-inside: avoid; }
          a { color: inherit; text-decoration-color: #59616C; }
          .footnote-ref a, .footnote-backref { text-decoration: none; }
        }
        """
    }

    private var previewFontFaceRule: String {
        guard purpose == .preview else { return "" }
        return """
        @font-face {
          font-family: "LXGW WenKai GB Lite";
          src: url("Fonts/LXGWWenKaiGBLite-Regular.ttf") format("truetype");
          font-style: normal;
          font-weight: 100 900;
          font-display: swap;
        }
        """
    }

    private func cssNumber(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
}

private enum HTMLFootnoteIdentifier {
    static func endnote(anchor: String) -> String {
        "plainleaf:fn:\(anchor)"
    }

    static func reference(anchor: String, occurrence: Int) -> String {
        "plainleaf:fnref:\(anchor):\(occurrence)"
    }
}
