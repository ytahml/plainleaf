import Foundation
import Markdown

struct MarkdownRenderer {
    private var nextID = 0

    mutating func parse(_ source: String) -> RenderedDocument {
        let document = Document(parsing: source)
        return RenderedDocument(blocks: blockChildren(of: document))
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
            return [make(.code(language: code.language, source: code.code))]
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
            return [make(.rawHTML(html.rawHTML))]
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

    private func tableKind(from table: Table) -> RenderedBlock.Kind {
        let alignments = table.columnAlignments.map { alignment -> TableAlignment? in
            switch alignment {
            case .left?: .left
            case .center?: .center
            case .right?: .right
            case nil: nil
            }
        }
        let header = table.head.children.compactMap { cell in
            (cell as? Table.Cell).map { inlineRuns(of: $0) }
        }
        let rows = Array(table.body.rows.map { row in
            row.children.compactMap { cell in
                (cell as? Table.Cell).map { inlineRuns(of: $0) }
            }
        })
        return .table(alignments: alignments, header: header, rows: rows)
    }

    private mutating func make(_ kind: RenderedBlock.Kind) -> RenderedBlock {
        defer { nextID += 1 }
        return RenderedBlock(id: nextID, kind: kind)
    }

    private func inlineRuns(of markup: Markup) -> [InlineRun] {
        markup.children.flatMap { inlineRuns(from: $0, style: [], destination: nil) }
    }

    private func inlineRuns(
        from markup: Markup,
        style: InlineRun.Style,
        destination: String?
    ) -> [InlineRun] {
        if let text = markup as? Markdown.Text {
            return [InlineRun(text: text.string, style: style, destination: destination)]
        }
        if let code = markup as? InlineCode {
            return [InlineRun(text: code.code, style: style.union(.code), destination: destination)]
        }
        if markup is SoftBreak {
            return [InlineRun(text: " ", style: style, destination: destination)]
        }
        if markup is LineBreak {
            return [InlineRun(text: "\n", style: style, destination: destination)]
        }
        if let html = markup as? InlineHTML {
            return [InlineRun(text: html.rawHTML, style: style.union(.rawHTML), destination: destination)]
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
            return [InlineRun(text: plain.plainText, style: nextStyle, destination: nextDestination)]
        }
        return []
    }

    private func plainText(of markup: Markup) -> String {
        if let text = markup as? Markdown.Text { return text.string }
        if let plain = markup as? PlainTextConvertibleMarkup, markup.childCount == 0 {
            return plain.plainText
        }
        return markup.children.map(plainText(of:)).joined()
    }
}
