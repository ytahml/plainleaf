import SwiftUI

@main
struct PlainleafApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(PlainleafAppDelegate.self) private var appDelegate

    init() {
        PlainleafTypography.prepareBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            PlainleafRootView(model: model)
                .frame(minWidth: 860, minHeight: 560)
                .onAppear { appDelegate.model = model }
        }
        .commands {
            PlainleafCommands(model: model)
        }
        .defaultSize(width: 1120, height: 760)
    }
}

@MainActor
final class PlainleafAppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model?.prepareToTerminate() != false else {
            sender.activate(ignoringOtherApps: true)
            sender.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
            return .terminateCancel
        }
        return .terminateNow
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
        CommandGroup(after: .saveItem) {
            Button("Export HTML…") { model.exportHTML() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.document == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…") { NotificationCenter.default.post(name: .plainleafPrint, object: nil) }
                .keyboardShortcut("p")
                .disabled(model.document == nil || model.mode == .source)
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
        CommandMenu("Navigate") {
            Button("Search Workspace") {
                NotificationCenter.default.post(name: .plainleafFocusWorkspaceSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(model.workspace == nil)

            Button("Clear Workspace Search") {
                model.clearWorkspaceSearch()
            }
            .disabled(!model.isWorkspaceSearchActive)
        }
        CommandMenu("Reading") {
            Button("Cycle View Mode") {
                model.cycleMode()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Show Source") { model.setMode(.source) }
                .disabled(model.document == nil || model.mode == .source)
            Button("Show Split View") { model.setMode(.split) }
                .disabled(model.document == nil || model.mode == .split)
            Button("Show Reading Mode") { model.setMode(.reading) }
                .disabled(model.document == nil || model.mode == .reading)

            Divider()

            Button(model.showsDocumentOutline ? "Collapse Document Outline" : "Expand Document Outline") {
                model.showsDocumentOutline.toggle()
            }
            .keyboardShortcut("o", modifiers: [.command, .option])
            .disabled(model.document == nil || model.mode == .source)

            Divider()

            Button("Increase Reading Text Size") {
                model.adjustReadingTextSize(by: ReadingAppearance.textSizeStep)
            }
            .keyboardShortcut("+")
            .disabled(
                model.document == nil
                    || model.mode == .source
                    || !model.readingAppearance.canIncreaseTextSize
            )

            Button("Decrease Reading Text Size") {
                model.adjustReadingTextSize(by: -ReadingAppearance.textSizeStep)
            }
            .keyboardShortcut("-")
            .disabled(
                model.document == nil
                    || model.mode == .source
                    || !model.readingAppearance.canDecreaseTextSize
            )

            Button("Reset Reading Appearance") {
                model.resetReadingAppearance()
            }
            .keyboardShortcut("0")
            .disabled(model.document == nil || model.mode == .source || model.readingAppearance.isStandard)
        }
    }
}
