import Foundation

struct RenderedDocument: Equatable {
    let blocks: [RenderedBlock]
}

struct RenderedBlock: Identifiable, Equatable {
    indirect enum Kind: Equatable {
        case heading(level: Int, runs: [InlineRun])
        case paragraph([InlineRun])
        case image(source: String?, alt: String)
        case code(language: String?, source: String)
        case blockQuote([RenderedBlock])
        case unorderedList([RenderedListItem])
        case orderedList(start: UInt, items: [RenderedListItem])
        case table(alignments: [TableAlignment?], header: [[InlineRun]], rows: [[[InlineRun]]])
        case thematicBreak
        case rawHTML(String)
    }

    let id: Int
    let kind: Kind
}

struct RenderedListItem: Equatable {
    enum CheckState: Equatable {
        case checked
        case unchecked
    }

    let checkState: CheckState?
    let blocks: [RenderedBlock]
}

enum TableAlignment: Equatable {
    case left
    case center
    case right
}

struct InlineRun: Equatable {
    struct Style: OptionSet, Equatable {
        let rawValue: Int

        static let strong = Style(rawValue: 1 << 0)
        static let emphasis = Style(rawValue: 1 << 1)
        static let strikethrough = Style(rawValue: 1 << 2)
        static let code = Style(rawValue: 1 << 3)
        static let rawHTML = Style(rawValue: 1 << 4)
    }

    let text: String
    let style: Style
    let destination: String?
}
