import AppKit
import CoreText
import SwiftUI

enum ThemePreference: String, CaseIterable, Identifiable {
    case system
    case paper
    case ink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .paper: "Light"
        case .ink: "Dark"
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
        canvas: .plainleaf(0xF0F2F5),
        chrome: .plainleaf(0xF7F8FA),
        surface: .plainleaf(0xFDFDFE),
        text: .plainleaf(0x202124),
        secondaryText: .plainleaf(0x59616C),
        accent: .plainleaf(0x075EAF),
        warmAccent: .plainleaf(0xA33A16),
        border: .plainleaf(0xD7DBE2),
        codeBackground: .plainleaf(0xEEF1F5),
        selection: .plainleaf(0xDFEBF8)
    )

    static let ink = PlainleafTheme(
        isDark: true,
        canvas: .plainleaf(0x121417),
        chrome: .plainleaf(0x191C20),
        surface: .plainleaf(0x20242A),
        text: .plainleaf(0xF1F3F5),
        secondaryText: .plainleaf(0xAAB0B8),
        accent: .plainleaf(0x78B2FF),
        warmAccent: .plainleaf(0xFF9A70),
        border: .plainleaf(0x383D45),
        codeBackground: .plainleaf(0x181B20),
        selection: .plainleaf(0x2A3C55)
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
    static let readingFamilyName = "LXGW WenKai GB Lite"
    static let readingPostScriptName = "LXGWWenKaiGBLite-Regular"
    static let bundledFontBaseURL = Bundle.module.resourceURL

    @discardableResult
    static func prepareBundledFonts() -> Bool {
        bundledReadingFontIsAvailable
    }

    static func readingFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if prepareBundledFonts(),
           let bundled = NSFont(name: readingPostScriptName, size: size) {
            let traits: [NSFontDescriptor.TraitKey: Any] = [.weight: weight]
            let descriptor = bundled.fontDescriptor.addingAttributes([.traits: traits])
            return NSFont(descriptor: descriptor, size: size) ?? bundled
        }

        return fallbackReadingFont(size: size, weight: weight)
    }

    private static let bundledReadingFontIsAvailable: Bool = {
        if NSFont(name: readingPostScriptName, size: 17) != nil {
            return true
        }
        guard let url = Bundle.module.url(
            forResource: "LXGWWenKaiGBLite-Regular",
            withExtension: "ttf",
            subdirectory: "Fonts"
        ) else {
            return false
        }
        var registrationError: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(
            url as CFURL,
            .process,
            &registrationError
        )
        return didRegister || NSFont(name: readingPostScriptName, size: 17) != nil
    }()

    private static func fallbackReadingFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
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
    static func plainleaf(_ hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
