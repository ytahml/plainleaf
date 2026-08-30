import Combine
import Foundation

@MainActor
final class DocumentSession: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case pending
        case saving
        case saved(Date)
        case failed(String)
        case conflict
    }

    let url: URL
    let workspaceURL: URL

    @Published var text: String {
        didSet {
            guard !isApplyingDiskText, text != oldValue else { return }
            saveState = .pending
            scheduleAutosave()
        }
    }
    @Published private(set) var saveState: SaveState = .idle
    @Published private(set) var conflictDiskText: String?

    private(set) var lastSavedText: String
    private var baseRevision: FileRevision
    private var autosaveTask: Task<Void, Never>?
    private var isApplyingDiskText = false

    init(url: URL, workspaceURL: URL) throws {
        try DocumentIO.validateEditableFile(url, inside: workspaceURL)
        let snapshot = try DocumentIO.read(url)
        self.url = url
        self.workspaceURL = workspaceURL
        self.text = snapshot.text
        self.lastSavedText = snapshot.text
        self.baseRevision = snapshot.revision
    }

    var hasUnsavedChanges: Bool { text != lastSavedText }
    var hasConflict: Bool { conflictDiskText != nil }

    func scheduleAutosave(delay: Duration = .milliseconds(450)) {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.saveNow()
            } catch {
                // Cancellation is expected when typing continues.
            }
        }
    }

    func saveNow() {
        autosaveTask?.cancel()
        guard !hasConflict, text != lastSavedText else {
            if hasConflict { saveState = .conflict }
            return
        }

        saveState = .saving
        do {
            let disk = try DocumentIO.read(url)
            guard disk.revision == baseRevision || disk.text == lastSavedText else {
                conflictDiskText = disk.text
                saveState = .conflict
                return
            }
            let saved = try DocumentIO.writeAtomically(text, to: url)
            lastSavedText = saved.text
            baseRevision = saved.revision
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    func refreshFromDisk() {
        do {
            let disk = try DocumentIO.read(url)
            guard disk.revision != baseRevision else { return }

            if !hasUnsavedChanges {
                applyDiskSnapshot(disk)
            } else if disk.text != lastSavedText {
                conflictDiskText = disk.text
                saveState = .conflict
                autosaveTask?.cancel()
            }
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    func resolveUsingDiskVersion() {
        guard conflictDiskText != nil else { return }
        do {
            applyDiskSnapshot(try DocumentIO.read(url))
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    func resolveKeepingLocalVersion() {
        guard conflictDiskText != nil else { return }
        do {
            baseRevision = try DocumentIO.revision(for: url)
            conflictDiskText = nil
            saveState = .pending
            saveNow()
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    private func applyDiskSnapshot(_ snapshot: DocumentSnapshot) {
        autosaveTask?.cancel()
        isApplyingDiskText = true
        text = snapshot.text
        isApplyingDiskText = false
        lastSavedText = snapshot.text
        baseRevision = snapshot.revision
        conflictDiskText = nil
        saveState = .idle
    }
}
