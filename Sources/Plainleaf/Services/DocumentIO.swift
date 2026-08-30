import CryptoKit
import Foundation

struct FileRevision: Equatable, Sendable {
    let digest: String
    let byteCount: Int
    let modificationDate: Date?
}

struct DocumentSnapshot: Equatable, Sendable {
    let text: String
    let revision: FileRevision
}

enum DocumentIOError: LocalizedError {
    case notUTF8
    case outsideWorkspace
    case unsupportedExtension

    var errorDescription: String? {
        switch self {
        case .notUTF8:
            "Plainleaf currently supports UTF-8 Markdown files only."
        case .outsideWorkspace:
            "The selected file is outside the authorized workspace."
        case .unsupportedExtension:
            "Plainleaf can edit .md, .markdown, and .mdown files only."
        }
    }
}

enum DocumentIO {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown"]

    static func read(_ url: URL) throws -> DocumentSnapshot {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard let text = String(data: data, encoding: .utf8) else {
            throw DocumentIOError.notUTF8
        }
        return DocumentSnapshot(text: text, revision: try revision(for: url, data: data))
    }

    static func revision(for url: URL) throws -> FileRevision {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try revision(for: url, data: data)
    }

    static func writeAtomically(_ text: String, to url: URL) throws -> DocumentSnapshot {
        guard let data = text.data(using: .utf8) else {
            throw DocumentIOError.notUTF8
        }
        try data.write(to: url, options: [.atomic])
        return DocumentSnapshot(text: text, revision: try revision(for: url, data: data))
    }

    static func validateEditableFile(_ url: URL, inside workspace: URL) throws {
        guard url.isDescendant(of: workspace) else {
            throw DocumentIOError.outsideWorkspace
        }
        guard markdownExtensions.contains(url.pathExtension.lowercased()) else {
            throw DocumentIOError.unsupportedExtension
        }
    }

    private static func revision(for url: URL, data: Data) throws -> FileRevision {
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return FileRevision(
            digest: digest,
            byteCount: values.fileSize ?? data.count,
            modificationDate: values.contentModificationDate
        )
    }
}
