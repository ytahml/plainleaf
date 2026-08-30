import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    private enum DefaultsKey {
        static let selectedDocument = "Plainleaf.SelectedDocument"
        static let readingMode = "Plainleaf.ReadingMode"
        static let theme = "Plainleaf.ThemePreference"
    }

    @Published private(set) var workspace: WorkspaceStore?
    @Published private(set) var document: DocumentSession?
    @Published var notice: String?
    @Published var mode: ReadingMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.readingMode) }
    }
    @Published var themePreference: ThemePreference {
        didSet { UserDefaults.standard.set(themePreference.rawValue, forKey: DefaultsKey.theme) }
    }

    private var diskMonitorTask: Task<Void, Never>?

    init() {
        self.mode = ReadingMode(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKey.readingMode) ?? ""
        ) ?? .source
        self.themePreference = ThemePreference(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKey.theme) ?? ""
        ) ?? .system

        if let restoredURL = WorkspaceStore.restoreLastWorkspace() {
            openWorkspace(restoredURL, persist: false)
        }
    }

    func showOpenWorkspacePanel() {
        let panel = NSOpenPanel()
        panel.title = "Open a Markdown folder"
        panel.message = "Plainleaf reads Markdown files in the folder you choose."
        panel.prompt = "Open Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openWorkspace(url, persist: true)
    }

    func openWorkspace(_ url: URL, persist: Bool = true) {
        guard flushCurrentDocumentBeforeLeaving() else { return }
        let store = WorkspaceStore(rootURL: url)
        workspace = store
        document = nil

        if persist {
            do {
                try store.persistBookmark()
            } catch {
                notice = "The folder opened, but Plainleaf could not remember its permission: \(error.localizedDescription)"
            }
        }

        if let path = UserDefaults.standard.string(forKey: DefaultsKey.selectedDocument),
           let selectedURL = store.url(forRelativePath: path),
           FileManager.default.fileExists(atPath: selectedURL.path) {
            openDocument(selectedURL)
        }
    }

    func openDocument(_ url: URL) {
        guard let workspace else { return }
        if document?.url.standardizedFileURL == url.standardizedFileURL { return }
        guard flushCurrentDocumentBeforeLeaving() else { return }

        do {
            let session = try DocumentSession(url: url, workspaceURL: workspace.rootURL)
            document = session
            if let path = workspace.relativePath(for: url) {
                UserDefaults.standard.set(path, forKey: DefaultsKey.selectedDocument)
            }
            startMonitoringDisk()
        } catch {
            notice = error.localizedDescription
        }
    }

    func createMarkdownFile() {
        guard let workspace else {
            showOpenWorkspacePanel()
            return
        }

        let panel = NSSavePanel()
        panel.title = "New Markdown File"
        panel.nameFieldStringValue = "Untitled.md"
        panel.directoryURL = workspace.rootURL
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, var url = panel.url else { return }
        if url.pathExtension.isEmpty {
            url.appendPathExtension("md")
        }

        do {
            try DocumentIO.validateEditableFile(url, inside: workspace.rootURL)
            guard !FileManager.default.fileExists(atPath: url.path) else {
                notice = "A file with that name already exists."
                return
            }
            _ = try DocumentIO.writeAtomically("", to: url)
            workspace.reload()
            openDocument(url)
        } catch {
            notice = error.localizedDescription
        }
    }

    func save() {
        document?.saveNow()
    }

    func toggleMode() {
        if mode == .source {
            document?.saveNow()
            mode = .reading
        } else {
            mode = .source
        }
    }

    func openLink(_ destination: String) {
        guard let workspace, let document else { return }

        if let webURL = URL(string: destination), let scheme = webURL.scheme?.lowercased() {
            if scheme == "http" || scheme == "https" || scheme == "mailto" {
                NSWorkspace.shared.open(webURL)
                return
            }
            if scheme != "file" {
                notice = "Plainleaf did not open an unsupported link scheme: \(scheme)"
                return
            }
        }

        let pathWithoutFragment = destination.split(separator: "#", maxSplits: 1).first.map(String.init) ?? destination
        let decoded = pathWithoutFragment.removingPercentEncoding ?? pathWithoutFragment
        let target: URL
        if decoded.hasPrefix("file://"), let fileURL = URL(string: decoded) {
            target = fileURL
        } else {
            target = document.url.deletingLastPathComponent().appendingPathComponent(decoded)
        }

        let normalized = target.standardizedFileURL
        guard workspace.contains(normalized) else {
            notice = "Plainleaf blocked a link outside the authorized workspace."
            return
        }
        if DocumentIO.markdownExtensions.contains(normalized.pathExtension.lowercased()) {
            openDocument(normalized)
        } else {
            NSWorkspace.shared.open(normalized)
        }
    }

    func clearNotice() {
        notice = nil
    }

    private func flushCurrentDocumentBeforeLeaving() -> Bool {
        guard let current = document else { return true }
        current.saveNow()
        if current.hasUnsavedChanges || current.hasConflict {
            notice = "Resolve or save the current document before opening another one."
            return false
        }
        return true
    }

    private func startMonitoringDisk() {
        diskMonitorTask?.cancel()
        diskMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    self?.document?.refreshFromDisk()
                } catch {
                    return
                }
            }
        }
    }
}
