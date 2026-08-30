import SwiftUI

struct DocumentContainerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var session: DocumentSession
    let theme: PlainleafTheme

    var body: some View {
        VStack(spacing: 0) {
            documentHeader

            if session.hasConflict {
                conflictBanner
            }

            Group {
                if model.mode == .source {
                    sourceSurface
                } else {
                    MarkdownReaderView(
                        source: session.text,
                        documentURL: session.url,
                        workspaceURL: session.workspaceURL,
                        theme: theme,
                        onOpenLink: model.openLink
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            statusBar
        }
        .background(theme.canvasColor)
    }

    private var documentHeader: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(relativeLocation.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(1)
                Text(session.url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .lineLimit(1)
            }

            Spacer(minLength: 20)

            ModeSwitch(model: model, theme: theme)
        }
        .padding(.horizontal, 22)
        .frame(height: 66)
        .background(theme.surfaceColor)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.borderColor.opacity(0.8)).frame(height: 1)
        }
    }

    private var sourceSurface: some View {
        ZStack {
            theme.canvasColor
            SourceEditor(text: $session.text, theme: theme)
                .frame(maxWidth: 860)
                .background(theme.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(theme.borderColor.opacity(0.7), lineWidth: 1)
                }
                .shadow(color: .black.opacity(theme.isDark ? 0.20 : 0.08), radius: 14, y: 6)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
    }

    private var conflictBanner: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.warmAccentColor)
                .frame(width: 4, height: 34)
                .accessibilityHidden(true)
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warmAccentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("This file changed outside Plainleaf")
                    .font(.system(size: 13, weight: .semibold))
                Text("Autosave is paused. Choose which version to keep.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryTextColor)
            }
            Spacer()
            Button("Use Disk Version") { session.resolveUsingDiskVersion() }
            Button("Keep My Version") { session.resolveKeepingLocalVersion() }
                .buttonStyle(.borderedProminent)
                .tint(theme.warmAccentColor)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 58)
        .background(theme.warmAccentColor.opacity(theme.isDark ? 0.12 : 0.08))
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.warmAccentColor.opacity(0.35)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text("MARKDOWN")
            Circle()
                .fill(theme.borderColor)
                .frame(width: 3, height: 3)
            Text("UTF-8")
            Spacer()
            saveStateLabel
        }
        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
        .foregroundStyle(theme.secondaryTextColor)
        .padding(.horizontal, 14)
        .frame(height: 29)
        .background(theme.surfaceColor)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.borderColor.opacity(0.7)).frame(height: 1)
        }
    }

    @ViewBuilder
    private var saveStateLabel: some View {
        switch session.saveState {
        case .idle:
            Label("On disk", systemImage: "circle.fill")
                .labelStyle(SaveStateLabelStyle(color: theme.accentColor))
        case .pending:
            Label("Waiting to save", systemImage: "circle.fill")
                .labelStyle(SaveStateLabelStyle(color: theme.warmAccentColor))
        case .saving:
            Label("Saving", systemImage: "circle.fill")
                .labelStyle(SaveStateLabelStyle(color: theme.warmAccentColor))
        case .saved:
            Label("Saved", systemImage: "circle.fill")
                .labelStyle(SaveStateLabelStyle(color: theme.accentColor))
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .lineLimit(1)
        case .conflict:
            Label("Conflict", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warmAccentColor)
        }
    }

    private var relativeLocation: String {
        let root = session.workspaceURL.standardizedFileURL.path
        let file = session.url.standardizedFileURL.path
        let relative = file.hasPrefix(root + "/")
            ? String(file.dropFirst(root.count + 1))
            : session.url.lastPathComponent
        let components = relative.split(separator: "/").dropLast()
        return components.isEmpty
            ? session.workspaceURL.lastPathComponent
            : components.joined(separator: " / ")
    }
}

private struct ModeSwitch: View {
    @ObservedObject var model: AppModel
    let theme: PlainleafTheme

    var body: some View {
        HStack(spacing: 2) {
            modeButton(.source, label: "Write", symbol: "pencil.line")
            modeButton(.reading, label: "Read", symbol: "book.pages")
        }
        .padding(3)
        .background(theme.codeBackgroundColor)
        .clipShape(Capsule())
        .overlay {
            Capsule().stroke(theme.borderColor.opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func modeButton(_ mode: ReadingMode, label: String, symbol: String) -> some View {
        let isSelected = model.mode == mode
        return Button {
            if !isSelected { model.toggleMode() }
        } label: {
            Label(label, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 11)
                .frame(height: 25)
                .background(isSelected ? theme.surfaceColor : Color.clear)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(isSelected ? 0.08 : 0), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? theme.textColor : theme.secondaryTextColor)
        .accessibilityLabel(label == "Write" ? "Show source editor" : "Show reading mode")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SaveStateLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(color)
            configuration.title
        }
    }
}
