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
        static let documentOutline = "Plainleaf.DocumentOutline"
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
    @Published var showsDocumentOutline: Bool {
        didSet { UserDefaults.standard.set(showsDocumentOutline, forKey: DefaultsKey.documentOutline) }
    }
    @Published var readingAppearance: ReadingAppearance {
        didSet { readingAppearance.persist() }
    }
    @Published var workspaceSearchQuery = "" {
        didSet { scheduleWorkspaceSearch() }
    }
    @Published private(set) var workspaceSearchResponse = WorkspaceSearchResponse(
        results: [],
        totalResultCount: 0,
        searchedFileCount: 0,
        unreadableFileCount: 0
    )
    @Published private(set) var isSearchingWorkspace = false
    @Published private(set) var sourceRevealRequest: SourceRevealRequest?
    @Published private(set) var activeHeadingAnchor: String?
    let previewScrollSync = PreviewScrollSyncController()

    private var diskMonitorTask: Task<Void, Never>?
    private var workspaceSearchTask: Task<Void, Never>?
    private var documentTextObservation: AnyCancellable?

    init() {
        self.mode = ReadingMode(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKey.readingMode) ?? ""
        ) ?? .source
        self.themePreference = ThemePreference(
            rawValue: UserDefaults.standard.string(forKey: DefaultsKey.theme) ?? ""
        ) ?? .system
        self.showsDocumentOutline = UserDefaults.standard.object(forKey: DefaultsKey.documentOutline) == nil
            ? true
            : UserDefaults.standard.bool(forKey: DefaultsKey.documentOutline)
        self.readingAppearance = ReadingAppearance.restore()

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
        clearWorkspaceSearch()

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
        sourceRevealRequest = nil
        if document?.url.standardizedFileURL == url.standardizedFileURL { return }
        guard flushCurrentDocumentBeforeLeaving() else { return }

        do {
            let session = try DocumentSession(url: url, workspaceURL: workspace.rootURL)
            document = session
            activeHeadingAnchor = nil
            previewScrollSync.reset()
            observeDocumentText(session)
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
            refreshWorkspaceSearch()
            openDocument(url)
        } catch {
            notice = error.localizedDescription
        }
    }

    func save() {
        document?.saveNow()
        refreshWorkspaceSearch()
    }

    func exportHTML() {
        guard let document else { return }

        let export = StandaloneHTMLExport(
            source: document.text,
            documentURL: document.url,
            workspaceURL: document.workspaceURL,
            theme: resolvedTheme,
            appearance: readingAppearance
        )
        let panel = NSSavePanel()
        panel.title = "Export Standalone HTML"
        panel.message = "Plainleaf embeds local images and saves one offline HTML file."
        panel.prompt = "Export"
        panel.nameFieldStringValue = export.suggestedFilename
        panel.directoryURL = document.url.deletingLastPathComponent()
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
        do {
            try export.write(to: destinationURL)
            notice = "Exported \(destinationURL.lastPathComponent) as standalone HTML."
        } catch {
            notice = "Plainleaf could not export HTML: \(error.localizedDescription)"
        }
    }

    func toggleMode() {
        setMode(mode == .source ? .reading : .source)
    }

    func cycleMode() {
        switch mode {
        case .source: setMode(.split)
        case .split: setMode(.reading)
        case .reading: setMode(.source)
        }
    }

    func setMode(_ newMode: ReadingMode) {
        guard newMode != mode else { return }
        if newMode == .split {
            previewScrollSync.prepareForSplit(from: mode)
        }
        if mode == .source, newMode != .source {
            document?.saveNow()
        }
        if mode == .split, newMode == .reading {
            document?.saveNow()
        }
        if newMode != .source {
            sourceRevealRequest = nil
        }
        mode = newMode
    }

    func adjustReadingTextSize(by delta: Double) {
        readingAppearance = readingAppearance.adjustingTextSize(by: delta)
    }

    func setReadingLeading(_ leading: ReadingLeading) {
        readingAppearance.leading = leading
    }

    func setReadingMeasure(_ measure: ReadingMeasure) {
        readingAppearance.measure = measure
    }

    func resetReadingAppearance() {
        readingAppearance = .standard
    }

    private var resolvedTheme: PlainleafTheme {
        .resolve(themePreference, systemAppearance: NSApp.effectiveAppearance)
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

    var isWorkspaceSearchActive: Bool {
        !workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func refreshWorkspaceSearch() {
        scheduleWorkspaceSearch(immediate: true)
    }

    func clearWorkspaceSearch() {
        workspaceSearchTask?.cancel()
        workspaceSearchQuery = ""
        workspaceSearchResponse = WorkspaceSearchResponse(
            results: [],
            totalResultCount: 0,
            searchedFileCount: 0,
            unreadableFileCount: 0
        )
        isSearchingWorkspace = false
    }

    func openSearchResult(_ result: WorkspaceSearchResult, match: WorkspaceSearchMatch?) {
        NotificationCenter.default.post(name: .plainleafResignWorkspaceSearch, object: nil)
        openDocument(result.file.url)
        guard document?.url.standardizedFileURL == result.file.url.standardizedFileURL else { return }
        guard let match else { return }

        setMode(.source)
        sourceRevealRequest = SourceRevealRequest(
            documentURL: result.file.url,
            query: workspaceSearchQuery,
            lineNumber: match.lineNumber
        )
    }

    func updateActiveHeading(_ anchor: String?, for documentURL: URL) {
        guard document?.url.standardizedFileURL == documentURL.standardizedFileURL,
              activeHeadingAnchor != anchor else {
            return
        }
        activeHeadingAnchor = anchor
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

    private func observeDocumentText(_ session: DocumentSession) {
        documentTextObservation = session.$text
            .dropFirst()
            .debounce(for: .milliseconds(180), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.isWorkspaceSearchActive else { return }
                self.refreshWorkspaceSearch()
            }
    }

    private func scheduleWorkspaceSearch(immediate: Bool = false) {
        workspaceSearchTask?.cancel()
        let query = workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let workspace else {
            workspaceSearchResponse = WorkspaceSearchResponse(
                results: [],
                totalResultCount: 0,
                searchedFileCount: 0,
                unreadableFileCount: 0
            )
            isSearchingWorkspace = false
            return
        }

        let files = workspace.markdownFiles
        let openDocumentOverride = document.map {
            WorkspaceSearchOverride(url: $0.url, contents: $0.text)
        }
        if !immediate {
            workspaceSearchResponse = WorkspaceSearchResponse(
                results: [],
                totalResultCount: 0,
                searchedFileCount: 0,
                unreadableFileCount: 0
            )
        }
        isSearchingWorkspace = true

        workspaceSearchTask = Task { [weak self] in
            do {
                if !immediate {
                    try await Task.sleep(for: .milliseconds(140))
                }
                try Task.checkCancellation()
                let response = try await WorkspaceSearchService.search(
                    query: query,
                    files: files,
                    openDocumentOverride: openDocumentOverride
                )
                try Task.checkCancellation()
                guard let self,
                      self.workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                    return
                }
                self.workspaceSearchResponse = response
                self.isSearchingWorkspace = false
            } catch is CancellationError {
                return
            } catch {
                guard let self,
                      self.workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                    return
                }
                self.workspaceSearchResponse = WorkspaceSearchResponse(
                    results: [],
                    totalResultCount: 0,
                    searchedFileCount: 0,
                    unreadableFileCount: files.count
                )
                self.isSearchingWorkspace = false
            }
        }
    }
}
