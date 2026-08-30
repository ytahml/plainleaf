import AppKit
import XCTest
@testable import Plainleaf

final class AppThemeTests: XCTestCase {
    func testFlexokiThemesKeepInterfaceColorsReadable() {
        for theme in [PlainleafTheme.paper, .ink] {
            XCTAssertGreaterThanOrEqual(contrast(theme.text, theme.surface), 7)
            XCTAssertGreaterThanOrEqual(contrast(theme.secondaryText, theme.surface), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(theme.accent, theme.surface), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(theme.warmAccent, theme.surface), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(theme.text, theme.chrome), 7)
            XCTAssertGreaterThanOrEqual(contrast(theme.secondaryText, theme.chrome), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(theme.accent, theme.chrome), 4.5)
            XCTAssertGreaterThanOrEqual(contrast(theme.text, theme.codeBackground), 7)
            XCTAssertNotEqual(theme.canvas, theme.chrome)
            XCTAssertNotEqual(theme.chrome, theme.surface)
            XCTAssertNotEqual(theme.codeBackground, theme.surface)
        }
    }

    func testSystemThemeResolutionFollowsAppearance() {
        XCTAssertEqual(
            PlainleafTheme.resolve(.system, systemAppearance: NSAppearance(named: .aqua)),
            .paper
        )
        XCTAssertEqual(
            PlainleafTheme.resolve(.system, systemAppearance: NSAppearance(named: .darkAqua)),
            .ink
        )
    }

    private func contrast(_ foreground: NSColor, _ background: NSColor) -> CGFloat {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: NSColor) -> CGFloat {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            XCTFail("Theme color must convert to sRGB")
            return 0
        }
        return 0.2126 * linear(rgb.redComponent)
            + 0.7152 * linear(rgb.greenComponent)
            + 0.0722 * linear(rgb.blueComponent)
    }

    private func linear(_ component: CGFloat) -> CGFloat {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}
