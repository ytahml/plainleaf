import Combine
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    static let bookmarkDefaultsKey = "Plainleaf.LastWorkspaceBookmark"

    let rootURL: URL
    @Published private(set) var nodes: [WorkspaceNode] = []
    @Published private(set) var errorMessage: String?

    private let didStartSecurityScope: Bool

    init(rootURL: URL) {
        self.rootURL = rootURL.standardizedFileURL
        self.didStartSecurityScope = rootURL.startAccessingSecurityScopedResource()
        reload()
    }

    deinit {
        if didStartSecurityScope {
            rootURL.stopAccessingSecurityScopedResource()
        }
    }

    var displayName: String { rootURL.lastPathComponent }

    func reload() {
        do {
            nodes = try Self.enumerate(rootURL)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func contains(_ url: URL) -> Bool {
        url.isDescendant(of: rootURL)
    }

    func relativePath(for url: URL) -> String? {
        let root = rootURL.standardizedFileURL.path
        let candidate = url.standardizedFileURL.path
        guard candidate == root || candidate.hasPrefix(root + "/") else { return nil }
        return String(candidate.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func url(forRelativePath path: String) -> URL? {
        let candidate = rootURL.appendingPathComponent(path).standardizedFileURL
        return contains(candidate) ? candidate : nil
    }

    func persistBookmark() throws {
        let data = try rootURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: Self.bookmarkDefaultsKey)
    }

    static func restoreLastWorkspace() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkDefaultsKey) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return nil
        }
        if stale, let refreshed = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(refreshed, forKey: bookmarkDefaultsKey)
        }
        return url
    }

    static func enumerate(_ directory: URL) throws -> [WorkspaceNode] {
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .isHiddenKey
        ]
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )

        return try urls.compactMap { url in
            let values = try url.resourceValues(forKeys: keys)
            guard values.isHidden != true, values.isSymbolicLink != true else { return nil }

            if values.isDirectory == true {
                return WorkspaceNode(url: url, kind: .directory, children: try enumerate(url))
            }
            if values.isRegularFile == true,
               DocumentIO.markdownExtensions.contains(url.pathExtension.lowercased()) {
                return WorkspaceNode(url: url, kind: .markdown, children: nil)
            }
            return nil
        }
        .sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
