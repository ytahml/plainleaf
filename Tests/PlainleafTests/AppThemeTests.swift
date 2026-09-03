import AppKit
import XCTest
@testable import Plainleaf

final class AppThemeTests: XCTestCase {
    func testReadingModePersistsSplitValue() {
        XCTAssertEqual(ReadingMode(rawValue: "split"), .split)
        XCTAssertEqual(ReadingMode.allCases, [.source, .split, .reading])
    }

    func testReadingAppearanceUsesBoundedHalfPointTextSizesAndNamedPresets() {
        XCTAssertEqual(ReadingAppearance(textSize: 12).textSize, 15.5)
        XCTAssertEqual(ReadingAppearance(textSize: 18.24).textSize, 18)
        XCTAssertEqual(ReadingAppearance(textSize: 18.26).textSize, 18.5)
        XCTAssertEqual(ReadingAppearance(textSize: 90).textSize, 22.5)
        XCTAssertEqual(ReadingAppearance(textSize: .infinity).textSize, 17.5)

        let adjusted = ReadingAppearance.standard
            .adjustingTextSize(by: ReadingAppearance.textSizeStep)
        XCTAssertEqual(adjusted.textSize, 18.5)
        XCTAssertEqual(adjusted.leading, .book)
        XCTAssertEqual(adjusted.measure, .balanced)
        XCTAssertEqual(ReadingLeading.compact.lineHeight, 1.58)
        XCTAssertEqual(ReadingLeading.book.lineHeight, 1.78)
        XCTAssertEqual(ReadingLeading.open.lineHeight, 1.94)
        XCTAssertEqual(ReadingMeasure.narrow.maximumWidth, 680)
        XCTAssertEqual(ReadingMeasure.balanced.maximumWidth, 796)
        XCTAssertEqual(ReadingMeasure.wide.maximumWidth, 940)
    }

    func testReadingAppearanceRoundTripsThroughIsolatedApplicationDefaults() throws {
        let suiteName = "PlainleafTests.ReadingAppearance.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(ReadingAppearance.restore(from: defaults), .standard)

        let expected = ReadingAppearance(
            textSize: 21.5,
            leading: .compact,
            measure: .wide
        )
        expected.persist(to: defaults)

        XCTAssertEqual(ReadingAppearance.restore(from: defaults), expected)
    }

    func testLightAndDarkThemesKeepInterfaceColorsReadable() {
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

    func testReadingTypographyLoadsBundledLXGWWenKai() {
        XCTAssertTrue(PlainleafTypography.prepareBundledFonts())

        let regular = PlainleafTypography.readingFont(size: 17.5)
        XCTAssertEqual(regular.familyName, PlainleafTypography.readingFamilyName)
        XCTAssertEqual(regular.fontName, PlainleafTypography.readingPostScriptName)

        let semibold = PlainleafTypography.readingFont(size: 21.5, weight: .semibold)
        XCTAssertEqual(semibold.familyName, PlainleafTypography.readingFamilyName)
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
