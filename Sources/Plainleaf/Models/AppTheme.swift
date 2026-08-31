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

enum ReadingMode: String, CaseIterable {
    case source
    case split
    case reading
}

struct PlainleafTheme: Equatable {
    let isDark: Bool
    let canvas: NSColor
    let chrome: NSColor
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
        canvas: .flexoki(0xECEAE3),
        chrome: .flexoki(0xF7F5EE),
        surface: .flexoki(0xFFFEFA),
        text: .flexoki(0x1C1B1A),
        secondaryText: .flexoki(0x6F6E69),
        accent: .flexoki(0x205EA6),
        warmAccent: .flexoki(0xAF3A03),
        border: .flexoki(0xDAD8CE),
        codeBackground: .flexoki(0xF3F4F6),
        selection: .flexoki(0xE6E4D9)
    )

    static let ink = PlainleafTheme(
        isDark: true,
        canvas: .flexoki(0x100F0F),
        chrome: .flexoki(0x1C1B1A),
        surface: .flexoki(0x171614),
        text: .flexoki(0xCECDC3),
        secondaryText: .flexoki(0x878580),
        accent: .flexoki(0x66A0C8),
        warmAccent: .flexoki(0xDA702C),
        border: .flexoki(0x343331),
        codeBackground: .flexoki(0x202226),
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
    var chromeColor: Color { Color(nsColor: chrome) }
    var surfaceColor: Color { Color(nsColor: surface) }
    var textColor: Color { Color(nsColor: text) }
    var secondaryTextColor: Color { Color(nsColor: secondaryText) }
    var accentColor: Color { Color(nsColor: accent) }
    var warmAccentColor: Color { Color(nsColor: warmAccent) }
    var borderColor: Color { Color(nsColor: border) }
    var codeBackgroundColor: Color { Color(nsColor: codeBackground) }
    var selectionColor: Color { Color(nsColor: selection) }
}

enum PlainleafTypography {
    static func readingFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let system = NSFont.systemFont(ofSize: size, weight: weight)
        let latinDescriptor = system.fontDescriptor.withDesign(.serif) ?? system.fontDescriptor
        let latin = NSFont(descriptor: latinDescriptor, size: size) ?? system

        let cjkNames = weight.rawValue >= NSFont.Weight.semibold.rawValue
            ? ["STSongti-SC-Bold", "PingFangSC-Semibold"]
            : ["STSongti-SC-Regular", "PingFangSC-Regular"]
        guard let cjk = cjkNames.lazy.compactMap({ NSFont(name: $0, size: size) }).first else {
            return latin
        }

        let descriptor = latin.fontDescriptor.addingAttributes([
            .cascadeList: [cjk.fontDescriptor]
        ])
        return NSFont(descriptor: descriptor, size: size) ?? latin
    }
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
