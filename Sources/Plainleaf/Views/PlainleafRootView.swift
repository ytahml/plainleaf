import AppKit
import SwiftUI

struct PlainleafRootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    private var theme: PlainleafTheme {
        let appearance = colorScheme == .dark
            ? NSAppearance(named: .darkAqua)
            : NSAppearance(named: .aqua)
        return .resolve(model.themePreference, systemAppearance: appearance)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 240, max: 340)
        } detail: {
            detail
        }
        .tint(theme.accentColor)
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.document != nil {
                    Button {
                        model.toggleMode()
                    } label: {
                        Label(
                            model.mode == .source ? "Read" : "Edit",
                            systemImage: model.mode == .source ? "book.pages" : "pencil.line"
                        )
                    }
                    .help(model.mode == .source ? "Show reading mode" : "Show Markdown source")
                    .accessibilityLabel(model.mode == .source ? "Show reading mode" : "Show source editor")
                }

                Picker("Theme", selection: $model.themePreference) {
                    ForEach(ThemePreference.allCases) { preference in
                        Text(preference.label).tag(preference)
                    }
                }
                .pickerStyle(.menu)
                .help("Choose Paper, Ink, or follow the system appearance")
            }
        }
        .alert("Plainleaf", isPresented: Binding(
            get: { model.notice != nil },
            set: { if !$0 { model.clearNotice() } }
        )) {
            Button("OK", role: .cancel) { model.clearNotice() }
        } message: {
            Text(model.notice ?? "")
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        if let workspace = model.workspace {
            WorkspaceSidebar(model: model, workspace: workspace, theme: theme)
        } else {
            VStack(spacing: 16) {
                PlainleafMark(size: 42, theme: theme)
                Text("Plainleaf")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Button("Open Folder…") { model.showOpenWorkspacePanel() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(theme.surfaceColor)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let document = model.document {
            DocumentContainerView(model: model, session: document, theme: theme)
                .id(document.url)
        } else {
            WelcomeView(model: model, theme: theme)
        }
    }
}

private struct WorkspaceSidebar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var workspace: WorkspaceStore
    let theme: PlainleafTheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                PlainleafMark(size: 26, theme: theme)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Plainleaf")
                        .font(.system(size: 13, weight: .semibold))
                    Text(workspace.displayName)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                        .lineLimit(1)
                }
                Spacer()
                Button { workspace.reload() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh workspace")
                .accessibilityLabel("Refresh workspace")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(workspace.nodes) { node in
                        WorkspaceNodeView(node: node, model: model, level: 0, theme: theme)
                    }
                }
                .padding(8)
            }

            Divider()

            HStack {
                Button { model.createMarkdownFile() } label: {
                    Label("New File", systemImage: "square.and.pencil")
                }
                .buttonStyle(.plain)
                Spacer()
                Button { model.showOpenWorkspacePanel() } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .help("Open another folder")
                .accessibilityLabel("Open another folder")
            }
            .font(.caption)
            .padding(12)
        }
        .background(theme.surfaceColor)
    }
}

private struct WorkspaceNodeView: View {
    let node: WorkspaceNode
    @ObservedObject var model: AppModel
    let level: Int
    let theme: PlainleafTheme
    @State private var isExpanded = true

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children ?? []) { child in
                    WorkspaceNodeView(node: child, model: model, level: level + 1, theme: theme)
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .lineLimit(1)
                    .padding(.vertical, 3)
            }
            .padding(.leading, CGFloat(level) * 8)
        } else {
            let selected = model.document?.url.standardizedFileURL == node.url.standardizedFileURL
            Button {
                model.openDocument(node.url)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "doc.plaintext")
                        .foregroundStyle(selected ? theme.accentColor : theme.secondaryTextColor)
                    Text(node.name)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(selected ? theme.accentColor.opacity(0.13) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(.leading, CGFloat(level) * 8)
            .accessibilityLabel("Open \(node.name)")
        }
    }
}

private struct WelcomeView: View {
    @ObservedObject var model: AppModel
    let theme: PlainleafTheme

    var body: some View {
        VStack(spacing: 22) {
            PlainleafMark(size: 84, theme: theme)
            VStack(spacing: 7) {
                Text("Plain files. Beautifully read.")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                Text(model.workspace == nil
                     ? "Choose a folder of Markdown files to begin."
                     : "Choose a Markdown file from the sidebar.")
                    .foregroundStyle(theme.secondaryTextColor)
            }
            if model.workspace == nil {
                Button("Open Folder…") { model.showOpenWorkspacePanel() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            Label("Local files only · No telemetry · No hidden workspace metadata", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.canvasColor)
    }
}

struct PlainleafMark: View {
    let size: CGFloat
    let theme: PlainleafTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(theme.accentColor)
            Path { path in
                path.move(to: CGPoint(x: size * 0.28, y: size * 0.72))
                path.addCurve(
                    to: CGPoint(x: size * 0.73, y: size * 0.25),
                    control1: CGPoint(x: size * 0.32, y: size * 0.39),
                    control2: CGPoint(x: size * 0.60, y: size * 0.26)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.28, y: size * 0.72),
                    control1: CGPoint(x: size * 0.71, y: size * 0.59),
                    control2: CGPoint(x: size * 0.48, y: size * 0.73)
                )
            }
            .fill(theme.canvasColor)
            Path { path in
                path.move(to: CGPoint(x: size * 0.34, y: size * 0.65))
                path.addLine(to: CGPoint(x: size * 0.65, y: size * 0.35))
            }
            .stroke(theme.accentColor, style: StrokeStyle(lineWidth: max(1.5, size * 0.035), lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
