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
    let border: NSColor
    let codeBackground: NSColor

    static let paper = PlainleafTheme(
        isDark: false,
        canvas: NSColor(calibratedRed: 0.969, green: 0.949, blue: 0.902, alpha: 1),
        surface: NSColor(calibratedRed: 0.988, green: 0.976, blue: 0.941, alpha: 1),
        text: NSColor(calibratedRed: 0.145, green: 0.137, blue: 0.118, alpha: 1),
        secondaryText: NSColor(calibratedRed: 0.39, green: 0.37, blue: 0.32, alpha: 1),
        accent: NSColor(calibratedRed: 0.24, green: 0.39, blue: 0.29, alpha: 1),
        border: NSColor(calibratedRed: 0.79, green: 0.76, blue: 0.68, alpha: 1),
        codeBackground: NSColor(calibratedRed: 0.925, green: 0.902, blue: 0.842, alpha: 1)
    )

    static let ink = PlainleafTheme(
        isDark: true,
        canvas: NSColor(calibratedRed: 0.095, green: 0.092, blue: 0.084, alpha: 1),
        surface: NSColor(calibratedRed: 0.125, green: 0.12, blue: 0.108, alpha: 1),
        text: NSColor(calibratedRed: 0.91, green: 0.885, blue: 0.82, alpha: 1),
        secondaryText: NSColor(calibratedRed: 0.67, green: 0.64, blue: 0.57, alpha: 1),
        accent: NSColor(calibratedRed: 0.47, green: 0.65, blue: 0.50, alpha: 1),
        border: NSColor(calibratedRed: 0.26, green: 0.25, blue: 0.22, alpha: 1),
        codeBackground: NSColor(calibratedRed: 0.075, green: 0.073, blue: 0.068, alpha: 1)
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
    var borderColor: Color { Color(nsColor: border) }
    var codeBackgroundColor: Color { Color(nsColor: codeBackground) }
}
