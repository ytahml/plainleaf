import SwiftUI

@main
struct PlainleafApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            PlainleafRootView(model: model)
                .frame(minWidth: 860, minHeight: 560)
        }
        .commands {
            PlainleafCommands(model: model)
        }
        .defaultSize(width: 1120, height: 760)
    }
}

private struct PlainleafCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Markdown File") { model.createMarkdownFile() }
                .keyboardShortcut("n")
            Button("Open Folder…") { model.showOpenWorkspacePanel() }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { model.save() }
                .keyboardShortcut("s")
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…") { NotificationCenter.default.post(name: .plainleafPrint, object: nil) }
                .keyboardShortcut("p")
                .disabled(model.document == nil || model.mode != .reading)
        }
        CommandMenu("Format") {
            Button("Bold") { NotificationCenter.default.post(name: .plainleafBold, object: nil) }
                .keyboardShortcut("b")
            Button("Italic") { NotificationCenter.default.post(name: .plainleafItalic, object: nil) }
                .keyboardShortcut("i")
            Button("Link") { NotificationCenter.default.post(name: .plainleafLink, object: nil) }
                .keyboardShortcut("k")
            Button("Inline Code") { NotificationCenter.default.post(name: .plainleafInlineCode, object: nil) }
                .keyboardShortcut("`", modifiers: [.command, .shift])
        }
        CommandMenu("Reading") {
            Button(model.mode == .source ? "Show Reading Mode" : "Show Source") {
                model.toggleMode()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
