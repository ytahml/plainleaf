import AppKit
import Highlighter
import SwiftUI

extension Notification.Name {
    static let plainleafPrint = Notification.Name("Plainleaf.Reader.Print")
}

struct MarkdownReaderView: View {
    let source: String
    let documentURL: URL
    let workspaceURL: URL
    let theme: PlainleafTheme
    let onOpenLink: (String) -> Void

    private var rendered: RenderedDocument {
        var renderer = MarkdownRenderer()
        return renderer.parse(source)
    }

    var body: some View {
        let document = rendered
        ScrollView {
            RenderedBlocksView(
                blocks: document.blocks,
                documentURL: documentURL,
                workspaceURL: workspaceURL,
                theme: theme
            )
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 66)
            .padding(.vertical, 62)
            .frame(maxWidth: 852, minHeight: 620, alignment: .topLeading)
            .background(theme.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(theme.borderColor.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: .black.opacity(theme.isDark ? 0.20 : 0.08), radius: 14, y: 6)
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(theme.canvasColor)
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "plainleaf", let destination = decodePlainleafLink(url) {
                onOpenLink(destination)
            } else {
                onOpenLink(url.absoluteString)
            }
            return .handled
        })
        .onReceive(NotificationCenter.default.publisher(for: .plainleafPrint)) { _ in
            printDocument(document)
        }
        .accessibilityLabel("Rendered Markdown document")
    }

    private func printDocument(_ document: RenderedDocument) {
        let printable = RenderedBlocksView(
            blocks: document.blocks,
            documentURL: documentURL,
            workspaceURL: workspaceURL,
            theme: .paper
        )
        .frame(width: 680, alignment: .leading)
        .padding(50)
        .background(PlainleafTheme.paper.canvasColor)

        let hostingView = NSHostingView(rootView: printable)
        hostingView.layoutSubtreeIfNeeded()
        let fitting = hostingView.fittingSize
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(width: 780, height: max(fitting.height, 900))
        )

        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = true
        NSPrintOperation(view: hostingView, printInfo: info).run()
    }

    private func decodePlainleafLink(_ url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "destination" })?
            .value
    }
}

private struct RenderedBlocksView: View {
    let blocks: [RenderedBlock]
    let documentURL: URL
    let workspaceURL: URL
    let theme: PlainleafTheme

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(blocks) { block in
                RenderedBlockView(
                    block: block,
                    documentURL: documentURL,
                    workspaceURL: workspaceURL,
                    theme: theme
                )
            }
        }
    }
}

private struct RenderedBlockView: View {
    let block: RenderedBlock
    let documentURL: URL
    let workspaceURL: URL
    let theme: PlainleafTheme

    @ViewBuilder
    var body: some View {
        switch block.kind {
        case let .heading(level, runs):
            if level == 1 {
                HStack(alignment: .top, spacing: 17) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.accentColor)
                        .frame(width: 4, height: 38)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                    InlineTextView(runs: runs, theme: theme, role: .heading(level))
                }
                .padding(.top, 8)
                .padding(.bottom, 5)
                .accessibilityAddTraits(.isHeader)
            } else {
                InlineTextView(runs: runs, theme: theme, role: .heading(level))
                    .padding(.top, 7)
                    .accessibilityAddTraits(.isHeader)
            }
        case let .paragraph(runs):
            InlineTextView(runs: runs, theme: theme, role: .body)
        case let .image(source, alt):
            SafeLocalImage(
                source: source,
                alt: alt,
                documentURL: documentURL,
                workspaceURL: workspaceURL,
                theme: theme
            )
        case let .code(language, source):
            HighlightedCodeBlock(language: language, source: source, theme: theme)
        case let .blockQuote(children):
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.warmAccentColor)
                    .frame(width: 3)
                RenderedBlocksView(
                    blocks: children,
                    documentURL: documentURL,
                    workspaceURL: workspaceURL,
                    theme: theme
                )
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.warmAccentColor.opacity(theme.isDark ? 0.09 : 0.06))
        case let .unorderedList(items):
            MarkdownList(
                items: items,
                start: nil,
                documentURL: documentURL,
                workspaceURL: workspaceURL,
                theme: theme
            )
        case let .orderedList(start, items):
            MarkdownList(
                items: items,
                start: start,
                documentURL: documentURL,
                workspaceURL: workspaceURL,
                theme: theme
            )
        case let .table(alignments, header, rows):
            MarkdownTable(alignments: alignments, header: header, rows: rows, theme: theme)
        case .thematicBreak:
            Divider().overlay(theme.borderColor)
        case let .rawHTML(html):
            VStack(alignment: .leading, spacing: 6) {
                Label("Raw HTML shown as text", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryTextColor)
                Text(html)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.codeBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.borderColor.opacity(0.7), lineWidth: 1)
            }
        }
    }
}

private struct MarkdownList: View {
    let items: [RenderedListItem]
    let start: UInt?
    let documentURL: URL
    let workspaceURL: URL
    let theme: PlainleafTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 10) {
                    marker(for: item, index: index)
                        .frame(width: 22, alignment: .trailing)
                        .foregroundStyle(item.checkState == .checked ? theme.accentColor : theme.secondaryTextColor)
                    RenderedBlocksView(
                        blocks: item.blocks,
                        documentURL: documentURL,
                        workspaceURL: workspaceURL,
                        theme: theme
                    )
                }
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private func marker(for item: RenderedListItem, index: Int) -> some View {
        switch item.checkState {
        case .checked?:
            Image(systemName: "checkmark.square.fill").accessibilityLabel("Completed task")
        case .unchecked?:
            Image(systemName: "square").accessibilityLabel("Incomplete task")
        case nil:
            if let start {
                Text("\(Int(start) + index).")
            } else {
                Text("•")
            }
        }
    }
}

private struct MarkdownTable: View {
    let alignments: [TableAlignment?]
    let header: [[InlineRun]]
    let rows: [[[InlineRun]]]
    let theme: PlainleafTheme

    var body: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(header.indices, id: \.self) { column in
                        cell(header[column], column: column, isHeader: true)
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                ForEach(rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(header.indices, id: \.self) { column in
                            cell(column < rows[row].count ? rows[row][column] : [], column: column, isHeader: false)
                        }
                    }
                    if row < rows.count - 1 {
                        Divider().gridCellUnsizedAxes(.horizontal)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .accessibilityLabel("Markdown table")
    }

    private func cell(_ runs: [InlineRun], column: Int, isHeader: Bool) -> some View {
        InlineTextView(runs: runs, theme: theme, role: isHeader ? .tableHeader : .tableCell)
            .frame(minWidth: 130, alignment: alignment(for: column))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isHeader ? theme.selectionColor : Color.clear)
    }

    private func alignment(for column: Int) -> Alignment {
        guard column < alignments.count else { return .leading }
        switch alignments[column] {
        case .center?: return Alignment.center
        case .right?: return Alignment.trailing
        default: return Alignment.leading
        }
    }
}

private struct SafeLocalImage: View {
    let source: String?
    let alt: String
    let documentURL: URL
    let workspaceURL: URL
    let theme: PlainleafTheme

    var body: some View {
        if let imageURL, let image = NSImage(contentsOf: imageURL) {
            VStack(alignment: .leading, spacing: 7) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 720, maxHeight: 560)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                if !alt.isEmpty {
                    Text(alt)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(alt.isEmpty ? "Local image" : alt)
        } else {
            HStack(spacing: 10) {
                Image(systemName: isRemote ? "network.slash" : "photo.badge.exclamationmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text(isRemote ? "Remote image blocked" : "Local image unavailable")
                        .fontWeight(.medium)
                    Text(alt.isEmpty ? (source ?? "Missing image source") : alt)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.codeBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var isRemote: Bool {
        guard let source, let url = URL(string: source), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    private var imageURL: URL? {
        guard let source, !isRemote else { return nil }
        let decoded = source.removingPercentEncoding ?? source
        let candidate = documentURL.deletingLastPathComponent().appendingPathComponent(decoded).standardizedFileURL
        guard candidate.isDescendant(of: workspaceURL),
              FileManager.default.fileExists(atPath: candidate.path) else { return nil }
        return candidate
    }
}

private struct HighlightedCodeBlock: View {
    let language: String?
    let source: String
    let theme: PlainleafTheme
    @State private var highlighted: AttributedString?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Circle()
                    .fill(theme.warmAccentColor)
                    .frame(width: 6, height: 6)
                Text(language?.isEmpty == false ? language!.uppercased() : "CODE")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1)
                Spacer()
            }
            .foregroundStyle(theme.secondaryTextColor)
            .padding(.horizontal, 14)
            .frame(height: 33)
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.borderColor.opacity(0.65)).frame(height: 1)
            }
            ScrollView(.horizontal) {
                Group {
                    if let highlighted {
                        Text(highlighted)
                    } else {
                        Text(source)
                    }
                }
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.codeBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.borderColor.opacity(0.7), lineWidth: 1)
        }
        .onAppear(perform: renderHighlight)
        .onChange(of: theme, initial: false) { _, _ in renderHighlight() }
    }

    private func renderHighlight() {
        guard let highlighter = Highlighter() else {
            highlighted = nil
            return
        }
        _ = highlighter.setTheme(theme.isDark ? "github-dark" : "github", withFont: "SFMono-Regular", ofSize: 13)
        let normalized = normalize(language)
        if let value = highlighter.highlight(source, as: normalized) ?? highlighter.highlight(source) {
            highlighted = AttributedString(value)
        } else {
            highlighted = nil
        }
    }

    private func normalize(_ language: String?) -> String? {
        guard let value = language?.lowercased(), !value.isEmpty else { return nil }
        return [
            "js": "javascript",
            "ts": "typescript",
            "py": "python",
            "sh": "bash",
            "zsh": "bash",
            "shell": "bash",
            "objc": "objectivec"
        ][value] ?? value
    }
}

private struct InlineTextView: View {
    enum Role {
        case body
        case heading(Int)
        case tableHeader
        case tableCell
    }

    let runs: [InlineRun]
    let theme: PlainleafTheme
    let role: Role
    @Environment(\.openURL) private var openURL

    @ViewBuilder
    var body: some View {
        if let destination = soleDestination, let url = encodedLink(destination) {
            Button {
                openURL(url)
            } label: {
                Text(attributedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(runs.map(\.text).joined())
            .accessibilityHint("Opens the linked document or website")
        } else {
            Text(attributedText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var soleDestination: String? {
        let destinations = Set(runs.compactMap(\.destination))
        guard destinations.count == 1, let destination = destinations.first,
              runs.allSatisfy({ $0.destination == destination }) else { return nil }
        return destination
    }

    private var attributedText: AttributedString {
        let result = NSMutableAttributedString()
        for run in runs {
            let part = NSMutableAttributedString(string: run.text)
            let range = NSRange(location: 0, length: (run.text as NSString).length)
            part.addAttributes(baseAttributes(for: run), range: range)
            if run.style.contains(.strikethrough) {
                part.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            if run.style.contains(.code) || run.style.contains(.rawHTML) {
                part.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: baseSize * 0.88, weight: .regular),
                    .foregroundColor: run.style.contains(.rawHTML) ? theme.secondaryText : theme.accent,
                    .backgroundColor: theme.codeBackground
                ], range: range)
            }
            if let destination = run.destination,
               let url = encodedLink(destination) {
                part.addAttributes([
                    .link: url,
                    .foregroundColor: theme.accent,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: range)
            }
            result.append(part)
        }
        return AttributedString(result)
    }

    private var baseSize: CGFloat {
        switch role {
        case .body: 17.5
        case let .heading(level): [0, 38, 28, 23, 20, 18, 17][min(max(level, 1), 6)]
        case .tableHeader, .tableCell: 14.5
        }
    }

    private func baseAttributes(for run: InlineRun) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = roleLineSpacing
        paragraph.paragraphSpacing = 2

        var font = readerFont(size: baseSize, weight: defaultWeight)
        if run.style.contains(.strong) {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if run.style.contains(.emphasis) {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return [
            .font: font,
            .foregroundColor: theme.text,
            .paragraphStyle: paragraph
        ]
    }

    private var defaultWeight: NSFont.Weight {
        switch role {
        case .heading, .tableHeader: .semibold
        default: .regular
        }
    }

    private var roleLineSpacing: CGFloat {
        switch role {
        case .body: 6
        case .heading: 3
        case .tableHeader, .tableCell: 3
        }
    }

    private func readerFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont(name: "NewYork-Regular", size: size) ?? NSFont.systemFont(ofSize: size)
        return weight == .regular ? base : NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
    }

    private func encodedLink(_ destination: String) -> URL? {
        var components = URLComponents()
        components.scheme = "plainleaf"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "destination", value: destination)]
        return components.url
    }
}
