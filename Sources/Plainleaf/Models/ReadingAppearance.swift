import Foundation

enum ReadingLeading: String, CaseIterable, Identifiable {
    case compact
    case book
    case open

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compact: "Compact"
        case .book: "Book"
        case .open: "Open"
        }
    }

    var lineHeight: Double {
        switch self {
        case .compact: 1.58
        case .book: 1.78
        case .open: 1.94
        }
    }
}

enum ReadingMeasure: String, CaseIterable, Identifiable {
    case narrow
    case balanced
    case wide

    var id: String { rawValue }

    var label: String {
        switch self {
        case .narrow: "Narrow"
        case .balanced: "Balanced"
        case .wide: "Wide"
        }
    }

    var maximumWidth: Double {
        switch self {
        case .narrow: 680
        case .balanced: 796
        case .wide: 940
        }
    }
}

struct ReadingAppearance: Equatable {
    private enum DefaultsKey {
        static let textSize = "Plainleaf.ReadingTextSize"
        static let leading = "Plainleaf.ReadingLeading"
        static let measure = "Plainleaf.ReadingMeasure"
    }

    static let minimumTextSize = 15.5
    static let maximumTextSize = 22.5
    static let textSizeStep = 1.0
    static let standard = ReadingAppearance(
        textSize: 17.5,
        leading: .book,
        measure: .balanced
    )

    var textSize: Double
    var leading: ReadingLeading
    var measure: ReadingMeasure

    init(
        textSize: Double = 17.5,
        leading: ReadingLeading = .book,
        measure: ReadingMeasure = .balanced
    ) {
        self.textSize = Self.normalizedTextSize(textSize)
        self.leading = leading
        self.measure = measure
    }

    var canDecreaseTextSize: Bool {
        textSize > Self.minimumTextSize
    }

    var canIncreaseTextSize: Bool {
        textSize < Self.maximumTextSize
    }

    var isStandard: Bool {
        self == Self.standard
    }

    func adjustingTextSize(by delta: Double) -> ReadingAppearance {
        ReadingAppearance(
            textSize: textSize + delta,
            leading: leading,
            measure: measure
        )
    }

    static func restore(from defaults: UserDefaults = .standard) -> ReadingAppearance {
        let storedTextSize = defaults.object(forKey: DefaultsKey.textSize) == nil
            ? standard.textSize
            : defaults.double(forKey: DefaultsKey.textSize)
        return ReadingAppearance(
            textSize: storedTextSize,
            leading: ReadingLeading(
                rawValue: defaults.string(forKey: DefaultsKey.leading) ?? ""
            ) ?? .book,
            measure: ReadingMeasure(
                rawValue: defaults.string(forKey: DefaultsKey.measure) ?? ""
            ) ?? .balanced
        )
    }

    func persist(to defaults: UserDefaults = .standard) {
        defaults.set(textSize, forKey: DefaultsKey.textSize)
        defaults.set(leading.rawValue, forKey: DefaultsKey.leading)
        defaults.set(measure.rawValue, forKey: DefaultsKey.measure)
    }

    private static func normalizedTextSize(_ value: Double) -> Double {
        guard value.isFinite else { return standardFallbackTextSize }
        let clamped = min(max(value, minimumTextSize), maximumTextSize)
        return (clamped * 2).rounded() / 2
    }

    private static let standardFallbackTextSize = 17.5
}
