import Foundation

struct WorkspaceNode: Identifiable, Hashable {
    enum Kind: Hashable {
        case directory
        case markdown
    }

    let url: URL
    let kind: Kind
    var children: [WorkspaceNode]?

    var id: String { url.standardizedFileURL.path }
    var name: String { url.lastPathComponent }
    var isDirectory: Bool { kind == .directory }
}

extension URL {
    func isDescendant(of root: URL) -> Bool {
        let rootComponents = root.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let candidateComponents = standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard candidateComponents.count >= rootComponents.count else { return false }
        return Array(candidateComponents.prefix(rootComponents.count)) == rootComponents
    }
}
