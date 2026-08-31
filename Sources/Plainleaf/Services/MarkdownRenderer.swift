import Foundation
import Markdown

struct MarkdownRenderer {
    private var nextID = 0
    private var footnoteDefinitions: [String: FootnotePreprocessor.Definition] = [:]
    private var referencedFootnoteLabels: [String] = []
    private var footnoteStates: [String: FootnoteReferenceState] = [:]
    private var footnoteIdentifiers = HeadingIdentifierGenerator()

    mutating func parse(_ source: String) -> RenderedDocument {
        nextID = 0
        referencedFootnoteLabels = []
        footnoteStates = [:]
        footnoteIdentifiers = HeadingIdentifierGenerator()

        let extraction = FootnotePreprocessor.extract(from: source)
        footnoteDefinitions = extraction.definitions
        let document = Document(parsing: FootnotePreprocessor.protectEscapedReferences(in: extraction.body))
        let blocks = blockChildren(of: document)

        var parsedDefinitions: [(label: String, blocks: [RenderedBlock])] = []
        var index = 0
        while index < referencedFootnoteLabels.count {
            let label = referencedFootnoteLabels[index]
            if let definition = footnoteDefinitions[label] {
                let definitionDocument = Document(
                    parsing: FootnotePreprocessor.protectEscapedReferences(in: definition.markdown)
                )
                parsedDefinitions.append((label, blockChildren(of: definitionDocument)))
            }
            index += 1
        }

        let footnotes = parsedDefinitions.compactMap { definition -> RenderedFootnote? in
            guard let state = footnoteStates[definition.label] else { return nil }
            return RenderedFootnote(
                label: definition.label,
                anchor: state.anchor,
                number: state.number,
                referenceCount: state.occurrenceCount,
                blocks: definition.blocks
            )
        }
        return RenderedDocument(blocks: blocks, footnotes: footnotes)
    }

    private mutating func blockChildren(of markup: Markup) -> [RenderedBlock] {
        markup.children.flatMap { block(from: $0) }
    }

    private mutating func block(from markup: Markup) -> [RenderedBlock] {
        if let heading = markup as? Heading {
            return [make(.heading(level: heading.level, runs: inlineRuns(of: heading)))]
        }
        if let paragraph = markup as? Paragraph {
            if paragraph.childCount == 1, let image = paragraph.child(at: 0) as? Markdown.Image {
                return [make(.image(source: image.source, alt: plainText(of: image)))]
            }
            return [make(.paragraph(inlineRuns(of: paragraph)))]
        }
        if let code = markup as? CodeBlock {
            return [make(.code(
                language: code.language,
                source: FootnotePreprocessor.restoreEscapedReferences(in: code.code)
            ))]
        }
        if let quote = markup as? BlockQuote {
            return [make(.blockQuote(blockChildren(of: quote)))]
        }
        if let list = markup as? UnorderedList {
            return [make(.unorderedList(list.listItems.map { listItem(from: $0) }))]
        }
        if let list = markup as? OrderedList {
            return [make(.orderedList(start: list.startIndex, items: list.listItems.map { listItem(from: $0) }))]
        }
        if markup is ThematicBreak {
            return [make(.thematicBreak)]
        }
        if let table = markup as? Table {
            return [make(tableKind(from: table))]
        }
        if let html = markup as? HTMLBlock {
            return [make(.rawHTML(FootnotePreprocessor.restoreEscapedReferences(in: html.rawHTML)))]
        }

        return blockChildren(of: markup)
    }

    private mutating func listItem(from item: ListItem) -> RenderedListItem {
        let state: RenderedListItem.CheckState?
        switch item.checkbox {
        case .checked?: state = .checked
        case .unchecked?: state = .unchecked
        case nil: state = nil
        }
        return RenderedListItem(checkState: state, blocks: blockChildren(of: item))
    }

    private mutating func tableKind(from table: Table) -> RenderedBlock.Kind {
        let alignments = table.columnAlignments.map { alignment -> TableAlignment? in
            switch alignment {
            case .left?: .left
            case .center?: .center
            case .right?: .right
            case nil: nil
            }
        }
        var header: [[InlineRun]] = []
        for cell in table.head.children {
            if let cell = cell as? Table.Cell {
                header.append(inlineRuns(of: cell))
            }
        }
        var rows: [[[InlineRun]]] = []
        for row in table.body.rows {
            var cells: [[InlineRun]] = []
            for cell in row.children {
                if let cell = cell as? Table.Cell {
                    cells.append(inlineRuns(of: cell))
                }
            }
            rows.append(cells)
        }
        return .table(alignments: alignments, header: header, rows: rows)
    }

    private mutating func make(_ kind: RenderedBlock.Kind) -> RenderedBlock {
        defer { nextID += 1 }
        return RenderedBlock(id: nextID, kind: kind)
    }

    private mutating func inlineRuns(of markup: Markup) -> [InlineRun] {
        markup.children.flatMap { inlineRuns(from: $0, style: [], destination: nil) }
    }

    private mutating func inlineRuns(
        from markup: Markup,
        style: InlineRun.Style,
        destination: String?
    ) -> [InlineRun] {
        if let text = markup as? Markdown.Text {
            return inlineRuns(fromText: text.string, style: style, destination: destination)
        }
        if let code = markup as? InlineCode {
            return [InlineRun(
                text: FootnotePreprocessor.restoreEscapedReferences(in: code.code),
                style: style.union(.code),
                destination: destination
            )]
        }
        if markup is SoftBreak {
            return [InlineRun(text: " ", style: style, destination: destination)]
        }
        if markup is LineBreak {
            return [InlineRun(text: "\n", style: style, destination: destination)]
        }
        if let html = markup as? InlineHTML {
            return [InlineRun(
                text: FootnotePreprocessor.restoreEscapedReferences(in: html.rawHTML),
                style: style.union(.rawHTML),
                destination: destination
            )]
        }
        if let image = markup as? Markdown.Image {
            let alt = plainText(of: image)
            return [InlineRun(text: alt.isEmpty ? "[Image]" : "[Image: \(alt)]", style: style, destination: nil)]
        }

        var nextStyle = style
        if markup is Strong { nextStyle.insert(.strong) }
        if markup is Emphasis { nextStyle.insert(.emphasis) }
        if markup is Strikethrough { nextStyle.insert(.strikethrough) }
        let nextDestination = (markup as? Link)?.destination ?? destination

        if markup.childCount > 0 {
            return markup.children.flatMap {
                inlineRuns(from: $0, style: nextStyle, destination: nextDestination)
            }
        }
        if let plain = markup as? PlainTextConvertibleMarkup {
            return [InlineRun(
                text: FootnotePreprocessor.restoreEscapedReferences(in: plain.plainText),
                style: nextStyle,
                destination: nextDestination
            )]
        }
        return []
    }

    private mutating func inlineRuns(
        fromText text: String,
        style: InlineRun.Style,
        destination: String?
    ) -> [InlineRun] {
        let restoredText = FootnotePreprocessor.restoreEscapedReferences(in: text)
        guard destination == nil, text.contains("[^") else {
            return [InlineRun(text: restoredText, style: style, destination: destination)]
        }

        var runs: [InlineRun] = []
        var searchStart = text.startIndex
        var plainStart = text.startIndex
        while searchStart < text.endIndex,
              let opening = text.range(of: "[^", range: searchStart..<text.endIndex),
              let closing = text.range(of: "]", range: opening.upperBound..<text.endIndex) {
            let rawLabel = String(text[opening.upperBound..<closing.lowerBound])
            let label = FootnotePreprocessor.normalizeLabel(rawLabel)
            guard !rawLabel.contains("["), footnoteDefinitions[label] != nil else {
                searchStart = opening.upperBound
                continue
            }

            if plainStart < opening.lowerBound {
                runs.append(InlineRun(
                    text: FootnotePreprocessor.restoreEscapedReferences(
                        in: String(text[plainStart..<opening.lowerBound])
                    ),
                    style: style,
                    destination: nil
                ))
            }
            runs.append(footnoteRun(label: label))
            plainStart = closing.upperBound
            searchStart = closing.upperBound
        }

        if plainStart < text.endIndex {
            runs.append(InlineRun(
                text: FootnotePreprocessor.restoreEscapedReferences(in: String(text[plainStart...])),
                style: style,
                destination: nil
            ))
        }
        return runs.isEmpty ? [InlineRun(text: restoredText, style: style, destination: nil)] : runs
    }

    private mutating func footnoteRun(label: String) -> InlineRun {
        var state: FootnoteReferenceState
        if let existing = footnoteStates[label] {
            state = existing
        } else {
            state = FootnoteReferenceState(
                number: referencedFootnoteLabels.count + 1,
                anchor: footnoteIdentifiers.identifier(for: label),
                occurrenceCount: 0
            )
            referencedFootnoteLabels.append(label)
        }
        state.occurrenceCount += 1
        footnoteStates[label] = state
        return InlineRun(
            text: "",
            style: [],
            destination: nil,
            footnoteReference: RenderedFootnoteReference(
                label: label,
                anchor: state.anchor,
                number: state.number,
                occurrence: state.occurrenceCount
            )
        )
    }

    private func plainText(of markup: Markup) -> String {
        if let text = markup as? Markdown.Text {
            return FootnotePreprocessor.restoreEscapedReferences(in: text.string)
        }
        if let plain = markup as? PlainTextConvertibleMarkup, markup.childCount == 0 {
            return FootnotePreprocessor.restoreEscapedReferences(in: plain.plainText)
        }
        return markup.children.map(plainText(of:)).joined()
    }
}

private struct FootnoteReferenceState {
    let number: Int
    let anchor: String
    var occurrenceCount: Int
}

private enum FootnotePreprocessor {
    private static let escapedReferenceSentinel = "\u{E000}plainleaf-escaped-footnote-open\u{E001}"

    struct Definition {
        let markdown: String
    }

    struct Extraction {
        let body: String
        let definitions: [String: Definition]
    }

    private struct Fence {
        let marker: Character
        let length: Int
    }

    private struct DefinitionStart {
        let label: String
        let content: String
        let column: Int
    }

    private struct ListItemRangeCollector: MarkupWalker {
        var ranges: [SourceRange] = []

        mutating func visitListItem(_ listItem: ListItem) {
            if let range = listItem.range {
                ranges.append(range)
            }
            descendInto(listItem)
        }
    }

    static func extract(from source: String) -> Extraction {
        let normalizedSource = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedSource.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let listItemRanges = lines.contains(where: { definitionStart(in: $0) != nil })
            ? rangesOfListItems(in: normalizedSource)
            : []
        var body: [String] = []
        var definitions: [String: Definition] = [:]
        var fence: Fence?
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if let currentFence = fence {
                body.append(line)
                if isClosingFence(line, for: currentFence) {
                    fence = nil
                }
                index += 1
                continue
            }
            if let openingFence = openingFence(in: line) {
                fence = openingFence
                body.append(line)
                index += 1
                continue
            }
            guard let start = definitionStart(in: line),
                  !isInsideListItem(
                    line: index + 1,
                    column: start.column,
                    ranges: listItemRanges
                  ),
                  definitions[start.label] == nil else {
                body.append(line)
                index += 1
                continue
            }

            var definitionLines = [start.content]
            index += 1
            while index < lines.count {
                if let continuation = continuationContent(in: lines[index]) {
                    definitionLines.append(continuation)
                    index += 1
                    continue
                }
                if lines[index].trimmingCharacters(in: .whitespaces).isEmpty,
                   index + 1 < lines.count,
                   continuationContent(in: lines[index + 1]) != nil {
                    definitionLines.append("")
                    index += 1
                    continue
                }
                break
            }

            definitions[start.label] = Definition(
                markdown: definitionLines
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            )
            body.append("")
        }

        return Extraction(body: body.joined(separator: "\n"), definitions: definitions)
    }

    static func normalizeLabel(_ label: String) -> String {
        label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }

    static func protectEscapedReferences(in source: String) -> String {
        var output = ""
        var index = source.startIndex
        while index < source.endIndex {
            guard source[index] == "\\" else {
                output.append(source[index])
                index = source.index(after: index)
                continue
            }

            let slashStart = index
            while index < source.endIndex, source[index] == "\\" {
                index = source.index(after: index)
            }
            let slashCount = source.distance(from: slashStart, to: index)
            let hasFootnoteOpening = index < source.endIndex && source[index...].hasPrefix("[^")
            if hasFootnoteOpening, slashCount.isMultiple(of: 2) == false {
                output += String(repeating: "\\", count: slashCount - 1)
                output += escapedReferenceSentinel
                index = source.index(index, offsetBy: 2)
            } else {
                output += String(repeating: "\\", count: slashCount)
            }
        }
        return output
    }

    static func restoreEscapedReferences(in text: String) -> String {
        text.replacingOccurrences(of: escapedReferenceSentinel, with: "[^")
    }

    private static func definitionStart(in line: String) -> DefinitionStart? {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3 else { return nil }
        let candidate = line.dropFirst(leadingSpaces)
        guard candidate.hasPrefix("[^") else { return nil }
        let labelStart = candidate.index(candidate.startIndex, offsetBy: 2)
        guard let closing = candidate.range(of: "]:", range: labelStart..<candidate.endIndex) else {
            return nil
        }
        let rawLabel = String(candidate[labelStart..<closing.lowerBound])
        let label = normalizeLabel(rawLabel)
        guard !label.isEmpty, !rawLabel.contains("[") else { return nil }
        let content = candidate[closing.upperBound...].drop(while: { $0 == " " || $0 == "\t" })
        return DefinitionStart(
            label: label,
            content: String(content),
            column: leadingSpaces + 1
        )
    }

    private static func rangesOfListItems(in source: String) -> [SourceRange] {
        let document = Document(parsing: source)
        var collector = ListItemRangeCollector()
        collector.visit(document)
        return collector.ranges
    }

    private static func isInsideListItem(
        line: Int,
        column: Int,
        ranges: [SourceRange]
    ) -> Bool {
        let location = SourceLocation(line: line, column: column, source: nil)
        return ranges.contains { $0.contains(location) }
    }

    private static func continuationContent(in line: String) -> String? {
        if line.hasPrefix("\t") {
            return String(line.dropFirst())
        }
        let spaces = line.prefix { $0 == " " }.count
        guard spaces >= 4 else { return nil }
        return String(line.dropFirst(4))
    }

    private static func openingFence(in line: String) -> Fence? {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3 else { return nil }
        let candidate = line.dropFirst(leadingSpaces)
        guard let marker = candidate.first, marker == "`" || marker == "~" else { return nil }
        let length = candidate.prefix { $0 == marker }.count
        guard length >= 3 else { return nil }
        return Fence(marker: marker, length: length)
    }

    private static func isClosingFence(_ line: String, for fence: Fence) -> Bool {
        let leadingSpaces = line.prefix { $0 == " " }.count
        guard leadingSpaces <= 3 else { return false }
        let candidate = line.dropFirst(leadingSpaces)
        let length = candidate.prefix { $0 == fence.marker }.count
        guard length >= fence.length else { return false }
        return candidate.dropFirst(length).allSatisfy(\.isWhitespace)
    }
}
