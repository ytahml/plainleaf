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
        case .paper: "Paper"
        case .ink: "Ink"
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
        canvas: NSColor(calibratedRed: 0.910, green: 0.894, blue: 0.855, alpha: 1),
        surface: NSColor(calibratedRed: 0.973, green: 0.961, blue: 0.925, alpha: 1),
        text: NSColor(calibratedRed: 0.145, green: 0.157, blue: 0.137, alpha: 1),
        secondaryText: NSColor(calibratedRed: 0.390, green: 0.404, blue: 0.363, alpha: 1),
        accent: NSColor(calibratedRed: 0.243, green: 0.420, blue: 0.302, alpha: 1),
        warmAccent: NSColor(calibratedRed: 0.659, green: 0.365, blue: 0.224, alpha: 1),
        border: NSColor(calibratedRed: 0.782, green: 0.757, blue: 0.698, alpha: 1),
        codeBackground: NSColor(calibratedRed: 0.910, green: 0.894, blue: 0.855, alpha: 1),
        selection: NSColor(calibratedRed: 0.824, green: 0.855, blue: 0.792, alpha: 1)
    )

    static let ink = PlainleafTheme(
        isDark: true,
        canvas: NSColor(calibratedRed: 0.098, green: 0.110, blue: 0.098, alpha: 1),
        surface: NSColor(calibratedRed: 0.137, green: 0.149, blue: 0.129, alpha: 1),
        text: NSColor(calibratedRed: 0.906, green: 0.898, blue: 0.859, alpha: 1),
        secondaryText: NSColor(calibratedRed: 0.604, green: 0.620, blue: 0.565, alpha: 1),
        accent: NSColor(calibratedRed: 0.471, green: 0.627, blue: 0.506, alpha: 1),
        warmAccent: NSColor(calibratedRed: 0.816, green: 0.506, blue: 0.349, alpha: 1),
        border: NSColor(calibratedRed: 0.235, green: 0.251, blue: 0.220, alpha: 1),
        codeBackground: NSColor(calibratedRed: 0.086, green: 0.098, blue: 0.082, alpha: 1),
        selection: NSColor(calibratedRed: 0.196, green: 0.267, blue: 0.208, alpha: 1)
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
