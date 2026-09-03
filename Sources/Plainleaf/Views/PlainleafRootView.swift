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
                .navigationSplitViewColumnWidth(min: 224, ideal: 272, max: 340)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .tint(theme.accentColor)
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Appearance", selection: $model.themePreference) {
                    ForEach(ThemePreference.allCases) { preference in
                        Label(preference.label, systemImage: preference.symbolName).tag(preference)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .help("Choose Light, Dark, or follow the system appearance")
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
            EmptyWorkspaceSidebar(model: model, theme: theme)
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

private struct EmptyWorkspaceSidebar: View {
    @ObservedObject var model: AppModel
    let theme: PlainleafTheme

    var body: some View {
        VStack(spacing: 0) {
            PlainleafSidebarHeader(title: "Plainleaf", subtitle: "Markdown on your Mac", theme: theme)

            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(theme.secondaryTextColor)
                    .accessibilityHidden(true)
                Text("No folder open")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Choose a folder to see its Markdown files.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.secondaryTextColor)
                    .multilineTextAlignment(.center)
                Button("Open folder") { model.showOpenWorkspacePanel() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.chromeColor)
    }
}

private struct WorkspaceSidebar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var workspace: WorkspaceStore
    let theme: PlainleafTheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                PlainleafMark(size: 28, theme: theme)
                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.displayName)
                        .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Text("Plainleaf")
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.secondaryTextColor)
                }
                Spacer(minLength: 8)
                Menu {
                    Button("Refresh notes", systemImage: "arrow.clockwise") {
                        workspace.reload()
                        model.refreshWorkspaceSearch()
                    }
                    Button("Open another folder", systemImage: "folder") {
                        model.showOpenWorkspacePanel()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(theme.surfaceColor.opacity(0.72))
                        .clipShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Workspace actions")
                .accessibilityLabel("Workspace actions")
            }
            .padding(.horizontal, 16)
            .frame(height: 70)

            WorkspaceSearchField(model: model, theme: theme)

            HStack {
                Text(model.isWorkspaceSearchActive ? "Results" : "Notes")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                Spacer()
                Text(workspace.markdownCount.formatted())
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryTextColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 7)

            if model.isWorkspaceSearchActive {
                WorkspaceSearchResultsView(model: model, theme: theme)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 3) {
                        ForEach(workspace.nodes) { node in
                            WorkspaceNodeView(node: node, model: model, level: 0, theme: theme)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                }
            }

            if !model.isWorkspaceSearchActive,
               model.mode != .source,
               let document = model.document {
                Divider().overlay(theme.borderColor.opacity(0.72))
                DocumentOutlineSection(model: model, session: document, theme: theme)
            }

            Divider().overlay(theme.borderColor.opacity(0.72))

            Button {
                model.createMarkdownFile()
            } label: {
                Label("New note", systemImage: "square.and.pencil")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .foregroundStyle(theme.isDark ? Color(nsColor: theme.canvas) : Color.white)
                    .background(theme.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(12)
            .help("Create a Markdown file")
        }
        .background(theme.chromeColor)
    }
}

private struct PlainleafSidebarHeader: View {
    let title: String
    let subtitle: String
    let theme: PlainleafTheme

    var body: some View {
        HStack(spacing: 12) {
            PlainleafMark(size: 28, theme: theme)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.secondaryTextColor)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 70)
    }
}

private struct WorkspaceNodeView: View {
    let node: WorkspaceNode
    @ObservedObject var model: AppModel
    let level: Int
    let theme: PlainleafTheme
    @State private var isExpanded = true
    @State private var isHovered = false

    var body: some View {
        if node.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(node.children ?? []) { child in
                    WorkspaceNodeView(node: child, model: model, level: level + 1, theme: theme)
                }
            } label: {
                Label(node.name, systemImage: "folder")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(1)
                    .padding(.vertical, 6)
            }
            .padding(.leading, CGFloat(level) * 9)
        } else {
            let selected = model.document?.url.standardizedFileURL == node.url.standardizedFileURL
            Button {
                model.openDocument(node.url)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selected ? "doc.text.fill" : "doc.text")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(selected ? theme.accentColor : theme.secondaryTextColor)
                        .frame(width: 16)
                    Text(node.url.deletingPathExtension().lastPathComponent)
                        .font(.system(size: 12.5, weight: selected ? .semibold : .regular, design: .rounded))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(selected ? theme.textColor : theme.secondaryTextColor)
                .contentShape(Rectangle())
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selected ? theme.selectionColor : (isHovered ? theme.surfaceColor.opacity(0.72) : Color.clear))
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, CGFloat(level) * 9)
            .onHover { isHovered = $0 }
            .accessibilityLabel("Open \(node.name)")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

private struct WelcomeView: View {
    @ObservedObject var model: AppModel
    let theme: PlainleafTheme

    var body: some View {
        ZStack {
            theme.canvasColor

            VStack(spacing: 0) {
                PlainleafMark(size: 54, theme: theme)
                    .padding(17)
                    .background(theme.surfaceColor)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(theme.borderColor.opacity(0.8), lineWidth: 1)
                    }
                    .shadow(color: Color(nsColor: theme.text).opacity(theme.isDark ? 0.13 : 0.06), radius: 20, y: 8)

                Text(model.workspace == nil ? "Your Markdown stays yours." : "Choose a note to begin.")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .tracking(-0.7)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)

                Text(model.workspace == nil
                     ? "Open a folder and work with ordinary files, entirely on your Mac."
                     : "Write in source, compare both views, or settle into reading.")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                    .padding(.top, 12)

                if model.workspace == nil {
                    Button("Open folder") { model.showOpenWorkspacePanel() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 24)
                }

                Label("Local files only. No hidden metadata.", systemImage: "lock.fill")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(theme.secondaryTextColor)
                    .padding(.top, 28)
            }
            .padding(48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
