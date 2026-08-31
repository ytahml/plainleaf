import XCTest
@testable import Plainleaf

@MainActor
final class PreviewScrollSyncTests: XCTestCase {
    func testRecordsLocalProgressWithoutPublishingWhenSyncIsDisabled() {
        let controller = PreviewScrollSyncController()

        controller.record(0.42, from: .source, synchronize: false)

        XCTAssertEqual(controller.progress(for: .source), 0.42, accuracy: 0.0001)
        XCTAssertEqual(controller.update.revision, 0)
    }

    func testPublishesClampedSynchronizedUpdates() {
        let controller = PreviewScrollSyncController()

        controller.record(1.4, from: .preview, synchronize: true)

        XCTAssertEqual(
            controller.update,
            PreviewScrollUpdate(revision: 1, origin: .preview, progress: 1)
        )
        XCTAssertEqual(controller.progress(for: .source), 1)
        XCTAssertEqual(controller.progress(for: .preview), 1)
    }

    func testSynchronizedUpdatesRefreshBothStoredPanePositionsInEitherDirection() {
        let controller = PreviewScrollSyncController()

        controller.record(0.26, from: .source, synchronize: true)

        XCTAssertEqual(controller.progress(for: .source), 0.26, accuracy: 0.0001)
        XCTAssertEqual(controller.progress(for: .preview), 0.26, accuracy: 0.0001)

        controller.record(0.73, from: .preview, synchronize: true)

        XCTAssertEqual(controller.progress(for: .source), 0.73, accuracy: 0.0001)
        XCTAssertEqual(controller.progress(for: .preview), 0.73, accuracy: 0.0001)
    }

    func testUnsynchronizedUpdatesKeepTheOtherPanePositionIndependent() {
        let controller = PreviewScrollSyncController()
        controller.record(0.18, from: .source, synchronize: false)
        controller.record(0.82, from: .preview, synchronize: false)

        XCTAssertEqual(controller.progress(for: .source), 0.18, accuracy: 0.0001)
        XCTAssertEqual(controller.progress(for: .preview), 0.82, accuracy: 0.0001)
        XCTAssertEqual(controller.update.revision, 0)
    }

    func testPreparingSplitCopiesTheVisibleModeProgressToBothPanes() {
        let controller = PreviewScrollSyncController()
        controller.record(0.31, from: .source, synchronize: false)
        controller.record(0.77, from: .preview, synchronize: false)

        controller.prepareForSplit(from: .source)

        XCTAssertEqual(controller.progress(for: .source), 0.31, accuracy: 0.0001)
        XCTAssertEqual(controller.progress(for: .preview), 0.31, accuracy: 0.0001)
        XCTAssertEqual(controller.update.origin, .source)

        controller.record(0.64, from: .preview, synchronize: false)
        controller.prepareForSplit(from: .reading)
        XCTAssertEqual(controller.progress(for: .source), 0.64, accuracy: 0.0001)
        XCTAssertEqual(controller.progress(for: .preview), 0.64, accuracy: 0.0001)
    }

    func testResetClearsBothStoredPositions() {
        let controller = PreviewScrollSyncController()
        controller.record(0.5, from: .source, synchronize: true)
        controller.record(0.8, from: .preview, synchronize: true)

        controller.reset()

        XCTAssertEqual(controller.progress(for: .source), 0)
        XCTAssertEqual(controller.progress(for: .preview), 0)
        XCTAssertEqual(controller.update.progress, 0)
    }

    func testScrollMetricsNormalizeAndClampOffsets() {
        XCTAssertEqual(
            PreviewScrollMetrics.progress(offset: 450, contentExtent: 1_200, viewportExtent: 300),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            PreviewScrollMetrics.offset(progress: 0.5, contentExtent: 1_200, viewportExtent: 300),
            450,
            accuracy: 0.0001
        )
        XCTAssertEqual(PreviewScrollMetrics.progress(offset: 20, contentExtent: 200, viewportExtent: 300), 0)
        XCTAssertEqual(PreviewScrollMetrics.offset(progress: 2, contentExtent: 800, viewportExtent: 300), 500)
    }
}
