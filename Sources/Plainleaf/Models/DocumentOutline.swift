import Foundation

struct DocumentOutlineItem: Identifiable, Equatable {
    let title: String
    let level: Int
    let anchor: String

    var id: String { anchor }
}

enum DocumentOutline {
    static func build(from source: String) -> [DocumentOutlineItem] {
        var renderer = MarkdownRenderer()
        let document = renderer.parse(source)
        var identifiers = HeadingIdentifierGenerator()
        return items(in: document.blocks, identifiers: &identifiers)
    }

    private static func items(
        in blocks: [RenderedBlock],
        identifiers: inout HeadingIdentifierGenerator
    ) -> [DocumentOutlineItem] {
        blocks.flatMap { block in
            switch block.kind {
            case let .heading(level, runs):
                let rawTitle = runs.map(\.text).joined()
                let title = rawTitle
                    .split(whereSeparator: \Character.isWhitespace)
                    .joined(separator: " ")
                return [DocumentOutlineItem(
                    title: title.isEmpty ? "Untitled section" : title,
                    level: min(max(level, 1), 6),
                    anchor: identifiers.identifier(for: rawTitle)
                )]
            case let .blockQuote(children):
                return items(in: children, identifiers: &identifiers)
            case let .unorderedList(listItems), let .orderedList(_, listItems):
                return listItems.flatMap {
                    items(in: $0.blocks, identifiers: &identifiers)
                }
            default:
                return []
            }
        }
    }
}

struct HeadingIdentifierGenerator {
    private var occurrences: [String: Int] = [:]

    mutating func identifier(for text: String) -> String {
        let raw = text.lowercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
        }.joined()
        let collapsed = raw
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        let base = collapsed.isEmpty ? "section" : collapsed
        let occurrence = occurrences[base, default: 0]
        occurrences[base] = occurrence + 1
        return occurrence == 0 ? base : "\(base)-\(occurrence + 1)"
    }
}
