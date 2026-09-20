import Foundation
import XCTest
@testable import Plainleaf

final class DocumentIOTests: XCTestCase {
    func testAtomicWriteRoundTripsUTF8() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("notes.md")
            try Data("first".utf8).write(to: file)

            let saved = try DocumentIO.writeAtomically("你好, Plainleaf\n", to: file)

            XCTAssertEqual(saved.text, "你好, Plainleaf\n")
            XCTAssertEqual(try DocumentIO.read(file), saved)
        }
    }

    func testEditableFileMustRemainInsideWorkspace() throws {
        try withTemporaryDirectory { workspace in
            let valid = workspace.appendingPathComponent("valid.md")
            XCTAssertNoThrow(try DocumentIO.validateEditableFile(valid, inside: workspace))

            let outside = workspace.deletingLastPathComponent().appendingPathComponent("outside.md")
            XCTAssertThrowsError(try DocumentIO.validateEditableFile(outside, inside: workspace))
            XCTAssertThrowsError(
                try DocumentIO.validateEditableFile(
                    workspace.appendingPathComponent("notes.txt"),
                    inside: workspace
                )
            )
        }
    }
}

@MainActor
final class DocumentSessionTests: XCTestCase {
    func testQuitFlushesPendingEditsAndRefusesExternalConflict() throws {
        let selectionKey = "Plainleaf.SelectedDocument"
        let previousSelection = UserDefaults.standard.object(forKey: selectionKey)
        defer { UserDefaults.standard.set(previousSelection, forKey: selectionKey) }
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("draft.md")
            try Data("base".utf8).write(to: file)
            let model = AppModel(restoreWorkspace: false)
            model.openWorkspace(directory, persist: false)
            model.openDocument(file)
            let session = try XCTUnwrap(model.document)
            session.text = "pending"
            XCTAssertTrue(model.prepareToTerminate())
            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "pending")

            session.text = "local"
            try Data("external".utf8).write(to: file, options: [.atomic])
            XCTAssertFalse(model.prepareToTerminate())
            XCTAssertEqual(session.text, "local")
            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "external")
            session.resolveUsingDiskVersion()
            XCTAssertTrue(model.prepareToTerminate())

            session.text = "still local"
            try Data([0xff]).write(to: file, options: [.atomic])
            XCTAssertFalse(model.prepareToTerminate())
            XCTAssertEqual(session.text, "still local")
            XCTAssertEqual(try Data(contentsOf: file), Data([0xff]))
        }
    }

    func testExplicitSaveWritesChangedText() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("draft.md")
            try Data("old".utf8).write(to: file)
            let session = try DocumentSession(url: file, workspaceURL: directory)

            session.text = "new"
            session.saveNow()

            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "new")
            XCTAssertFalse(session.hasUnsavedChanges)
            XCTAssertFalse(session.hasConflict)
        }
    }

    func testExternalChangeStopsOverwrite() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("draft.md")
            try Data("base".utf8).write(to: file)
            let session = try DocumentSession(url: file, workspaceURL: directory)

            session.text = "local"
            try Data("external".utf8).write(to: file, options: [.atomic])
            session.saveNow()

            XCTAssertTrue(session.hasConflict)
            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "external")
            XCTAssertEqual(session.text, "local")
        }
    }

    func testCleanSessionReloadsExternalChange() throws {
        try withTemporaryDirectory { directory in
            let file = directory.appendingPathComponent("draft.md")
            try Data("base".utf8).write(to: file)
            let session = try DocumentSession(url: file, workspaceURL: directory)

            try Data("external".utf8).write(to: file, options: [.atomic])
            session.refreshFromDisk()

            XCTAssertEqual(session.text, "external")
            XCTAssertFalse(session.hasConflict)
        }
    }
}

@MainActor
final class WorkspaceStoreTests: XCTestCase {
    func testEnumerationFiltersHiddenUnsupportedAndSymlinkEntries() throws {
        try withTemporaryDirectory { directory in
            let nested = directory.appendingPathComponent("Docs", isDirectory: true)
            try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
            try Data("# Visible".utf8).write(to: nested.appendingPathComponent("Visible.md"))
            try Data("ignore".utf8).write(to: directory.appendingPathComponent("notes.txt"))
            try Data("hidden".utf8).write(to: directory.appendingPathComponent(".hidden.md"))
            try FileManager.default.createSymbolicLink(
                at: directory.appendingPathComponent("linked.md"),
                withDestinationURL: nested.appendingPathComponent("Visible.md")
            )

            let nodes = try WorkspaceStore.enumerate(directory)

            XCTAssertEqual(nodes.map(\.name), ["Docs"])
            XCTAssertEqual(nodes.first?.children?.map(\.name), ["Visible.md"])

            let store = WorkspaceStore(rootURL: directory)
            XCTAssertEqual(store.markdownFiles.map(\.relativePath), ["Docs/Visible.md"])
        }
    }
}

private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlainleafTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}
