import Foundation

struct StandaloneHTMLExport {
    let suggestedFilename: String
    private let contents: Data

    init(
        source: String,
        documentURL: URL,
        workspaceURL: URL,
        theme: PlainleafTheme,
        appearance: ReadingAppearance
    ) {
        var renderer = HTMLDocumentRenderer(
            documentURL: documentURL,
            workspaceURL: workspaceURL,
            theme: theme,
            appearance: appearance,
            purpose: .standalone
        )
        self.suggestedFilename = documentURL
            .deletingPathExtension()
            .lastPathComponent
            .appending(".html")
        self.contents = Data(renderer.render(source).utf8)
    }

    func write(to destinationURL: URL) throws {
        try contents.write(to: destinationURL, options: .atomic)
    }
}
