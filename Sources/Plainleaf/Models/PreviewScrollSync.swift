import Combine
import Foundation

enum PreviewScrollOrigin: Equatable, Sendable {
    case source
    case preview
}

struct PreviewScrollUpdate: Equatable, Sendable {
    let revision: Int
    let origin: PreviewScrollOrigin
    let progress: Double
}

enum PreviewScrollMetrics {
    static func progress(offset: Double, contentExtent: Double, viewportExtent: Double) -> Double {
        let maximum = max(0, contentExtent - viewportExtent)
        guard maximum > 0, offset.isFinite else { return 0 }
        return min(max(offset / maximum, 0), 1)
    }

    static func offset(progress: Double, contentExtent: Double, viewportExtent: Double) -> Double {
        let maximum = max(0, contentExtent - viewportExtent)
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1) * maximum
    }
}

@MainActor
final class PreviewScrollSyncController: ObservableObject {
    @Published private(set) var update = PreviewScrollUpdate(
        revision: 0,
        origin: .source,
        progress: 0
    )

    private var sourceProgress: Double = 0
    private var previewProgress: Double = 0

    func record(_ progress: Double, from origin: PreviewScrollOrigin, synchronize: Bool) {
        let normalized = Self.clamp(progress)
        switch origin {
        case .source: sourceProgress = normalized
        case .preview: previewProgress = normalized
        }

        guard synchronize else { return }
        sourceProgress = normalized
        previewProgress = normalized
        update = PreviewScrollUpdate(
            revision: update.revision + 1,
            origin: origin,
            progress: normalized
        )
    }

    func prepareForSplit(from mode: ReadingMode) {
        let origin: PreviewScrollOrigin
        let progress: Double
        switch mode {
        case .source:
            origin = .source
            progress = sourceProgress
        case .reading:
            origin = .preview
            progress = previewProgress
        case .split:
            origin = update.origin
            progress = update.progress
        }

        sourceProgress = progress
        previewProgress = progress
        update = PreviewScrollUpdate(
            revision: update.revision + 1,
            origin: origin,
            progress: progress
        )
    }

    func progress(for origin: PreviewScrollOrigin) -> Double {
        switch origin {
        case .source: sourceProgress
        case .preview: previewProgress
        }
    }

    func reset() {
        sourceProgress = 0
        previewProgress = 0
        update = PreviewScrollUpdate(
            revision: update.revision + 1,
            origin: .source,
            progress: 0
        )
    }

    private static func clamp(_ progress: Double) -> Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }
}
