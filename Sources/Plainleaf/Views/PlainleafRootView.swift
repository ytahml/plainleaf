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
                .navigationSplitViewColumnWidth(min: 210, ideal: 258, max: 340)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .tint(theme.accentColor)
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.workspace != nil {
                    Button { model.createMarkdownFile() } label: {
                        Label("New Markdown File", systemImage: "square.and.pencil")
                    }
                    .help("Create a Markdown file")
                }

                Picker("Theme", selection: $model.themePreference) {
                    ForEach(ThemePreference.allCases) { preference in
                        Label(preference.label, systemImage: preference.symbolName).tag(preference)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .help("Choose Flexoki Light, Flexoki Dark, or follow the system appearance")
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
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    PlainleafMark(size: 30, theme: theme)
                    Text("PLAINLEAF")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)

                Spacer()

                VStack(alignment: .leading, spacing: 9) {
                    Text("No folder open")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Open a folder to see its Markdown files here.")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Folder…") { model.showOpenWorkspacePanel() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            HStack(spacing: 11) {
                PlainleafMark(size: 31, theme: theme)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PLAINLEAF")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(theme.secondaryTextColor)
                    Text(workspace.displayName)
                        .font(.system(size: 15, weight: .semibold))
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
            .padding(.horizontal, 16)
            .padding(.vertical, 15)

            HStack {
                Text("LIBRARY")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                Spacer()
                Text("\(workspace.markdownCount) \(workspace.markdownCount == 1 ? "NOTE" : "NOTES")")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(theme.secondaryTextColor)
            .padding(.horizontal, 16)
            .padding(.top, 9)
            .padding(.bottom, 7)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(workspace.nodes) { node in
                        WorkspaceNodeView(node: node, model: model, level: 0, theme: theme)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }

            Rectangle()
                .fill(theme.borderColor.opacity(0.75))
                .frame(height: 1)

            HStack {
                Button { model.createMarkdownFile() } label: {
                    Label("New note", systemImage: "plus")
                }
                .buttonStyle(.plain)
                Spacer()
                Button { model.showOpenWorkspacePanel() } label: {
                    Label("Switch folder", systemImage: "folder")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .help("Open another folder")
                .accessibilityLabel("Open another folder")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(theme.secondaryTextColor)
            .padding(.horizontal, 16)
            .frame(height: 42)
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
                Label(node.name, systemImage: "folder.fill")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(1)
                    .padding(.vertical, 5)
            }
            .padding(.leading, CGFloat(level) * 8)
        } else {
            let selected = model.document?.url.standardizedFileURL == node.url.standardizedFileURL
            Button {
                model.openDocument(node.url)
            } label: {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(selected ? theme.accentColor : Color.clear)
                        .frame(width: 3, height: 18)
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(selected ? theme.accentColor : theme.secondaryTextColor)
                    Text(node.url.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected ? theme.selectionColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
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
        ZStack {
            theme.canvasColor

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("A QUIET PLACE FOR MARKDOWN")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(theme.accentColor)
                    Text("Plain files,\nset in type.")
                        .font(.system(size: 42, weight: .medium, design: .serif))
                        .tracking(-1.1)
                        .padding(.top, 17)
                    Text(model.workspace == nil
                         ? "Open a folder. Plainleaf keeps every note as ordinary Markdown and works entirely on your Mac."
                         : "Choose a note from the library to write in source or settle into reading mode.")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.secondaryTextColor)
                        .lineSpacing(4)
                        .frame(maxWidth: 390, alignment: .leading)
                        .padding(.top, 16)
                    if model.workspace == nil {
                        Button("Open a Markdown folder…") { model.showOpenWorkspacePanel() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .padding(.top, 25)
                    }
                    Spacer()
                    Label("Local only · No hidden metadata", systemImage: "lock")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(theme.secondaryTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: 500, alignment: .leading)
                .padding(52)

                PaperStack(theme: theme)
                    .frame(width: 260, height: 360)
                    .padding(.trailing, 62)
            }
            .frame(maxWidth: 980)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PaperStack: View {
    let theme: PlainleafTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.selectionColor)
                .frame(width: 214, height: 286)
                .rotationEffect(.degrees(5))
                .offset(x: 15, y: 10)
            RoundedRectangle(cornerRadius: 3)
                .fill(theme.surfaceColor)
                .frame(width: 214, height: 286)
                .rotationEffect(.degrees(-3))
                .shadow(color: .black.opacity(theme.isDark ? 0.22 : 0.10), radius: 16, y: 8)
            VStack(alignment: .leading, spacing: 12) {
                PlainleafMark(size: 36, theme: theme)
                Spacer()
                Rectangle().fill(theme.textColor).frame(width: 118, height: 5)
                Rectangle().fill(theme.borderColor).frame(width: 150, height: 3)
                Rectangle().fill(theme.borderColor).frame(width: 126, height: 3)
                HStack(spacing: 5) {
                    Circle().fill(theme.warmAccentColor).frame(width: 5, height: 5)
                    Text("MARKDOWN")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(theme.secondaryTextColor)
                }
            }
            .frame(width: 164, height: 228, alignment: .leading)
            .rotationEffect(.degrees(-3))
        }
        .accessibilityHidden(true)
    }
}

struct PlainleafMark: View {
    let size: CGFloat
    let theme: PlainleafTheme

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size * 0.16, y: size * 0.82))
                path.addCurve(
                    to: CGPoint(x: size * 0.86, y: size * 0.12),
                    control1: CGPoint(x: size * 0.18, y: size * 0.36),
                    control2: CGPoint(x: size * 0.58, y: size * 0.13)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.16, y: size * 0.82),
                    control1: CGPoint(x: size * 0.85, y: size * 0.61),
                    control2: CGPoint(x: size * 0.51, y: size * 0.88)
                )
            }
            .fill(theme.accentColor)
            Path { path in
                path.move(to: CGPoint(x: size * 0.25, y: size * 0.74))
                path.addLine(to: CGPoint(x: size * 0.70, y: size * 0.29))
            }
            .stroke(
                theme.surfaceColor,
                style: StrokeStyle(lineWidth: max(1.5, size * 0.055), lineCap: .round)
            )
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private extension ThemePreference {
    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .paper: "sun.max"
        case .ink: "moon.stars"
        }
    }
}

private extension WorkspaceStore {
    var markdownCount: Int {
        func count(_ nodes: [WorkspaceNode]) -> Int {
            nodes.reduce(0) { result, node in
                result + (node.isDirectory ? count(node.children ?? []) : 1)
            }
        }
        return count(nodes)
    }
}
