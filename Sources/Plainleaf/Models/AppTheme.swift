import AppKit
import SwiftUI

enum ThemePreference: String, CaseIterable, Identifiable {
    case system
    case paper
    case ink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .paper: "Flexoki Light"
        case .ink: "Flexoki Dark"
        }
    }
}

enum ReadingMode: String {
    case source
    case reading
}

struct PlainleafTheme: Equatable {
    let isDark: Bool
    let canvas: NSColor
    let surface: NSColor
    let text: NSColor
    let secondaryText: NSColor
    let accent: NSColor
    let warmAccent: NSColor
    let border: NSColor
    let codeBackground: NSColor
    let selection: NSColor

    static let paper = PlainleafTheme(
        isDark: false,
        canvas: .flexoki(0xF2F0E5),
        surface: .flexoki(0xFFFCF0),
        text: .flexoki(0x100F0F),
        secondaryText: .flexoki(0x6F6E69),
        accent: .flexoki(0x205EA6),
        warmAccent: .flexoki(0xBC5215),
        border: .flexoki(0xDAD8CE),
        codeBackground: .flexoki(0xF2F0E5),
        selection: .flexoki(0xE6E4D9)
    )

    static let ink = PlainleafTheme(
        isDark: true,
        canvas: .flexoki(0x100F0F),
        surface: .flexoki(0x1C1B1A),
        text: .flexoki(0xCECDC3),
        secondaryText: .flexoki(0x878580),
        accent: .flexoki(0x66A0C8),
        warmAccent: .flexoki(0xDA702C),
        border: .flexoki(0x343331),
        codeBackground: .flexoki(0x282726),
        selection: .flexoki(0x343331)
    )

    static func resolve(_ preference: ThemePreference, systemAppearance: NSAppearance?) -> PlainleafTheme {
        switch preference {
        case .paper:
            return .paper
        case .ink:
            return .ink
        case .system:
            let match = systemAppearance?.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? .ink : .paper
        }
    }

    var canvasColor: Color { Color(nsColor: canvas) }
    var surfaceColor: Color { Color(nsColor: surface) }
    var textColor: Color { Color(nsColor: text) }
    var secondaryTextColor: Color { Color(nsColor: secondaryText) }
    var accentColor: Color { Color(nsColor: accent) }
    var warmAccentColor: Color { Color(nsColor: warmAccent) }
    var borderColor: Color { Color(nsColor: border) }
    var codeBackgroundColor: Color { Color(nsColor: codeBackground) }
    var selectionColor: Color { Color(nsColor: selection) }
}

private extension NSColor {
    static func flexoki(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
