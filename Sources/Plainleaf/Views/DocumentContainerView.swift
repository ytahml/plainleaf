import SwiftUI

struct DocumentContainerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var session: DocumentSession
    let theme: PlainleafTheme

    var body: some View {
        VStack(spacing: 0) {
            if session.hasConflict {
                conflictBanner
            }

            Group {
                if model.mode == .source {
                    SourceEditor(text: $session.text, theme: theme)
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

    private var conflictBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("This file changed outside Plainleaf")
                    .font(.system(size: 13, weight: .semibold))
                Text("Autosave is paused so neither version is overwritten silently.")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryTextColor)
            }
            Spacer()
            Button("Use Disk Version") { session.resolveUsingDiskVersion() }
            Button("Keep My Version") { session.resolveKeepingLocalVersion() }
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(Color.orange.opacity(theme.isDark ? 0.16 : 0.11))
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
    }

    private var statusBar: some View {
        HStack(spacing: 7) {
            Image(systemName: model.mode == .source ? "chevron.left.forwardslash.chevron.right" : "book.pages")
            Text(model.mode == .source ? "Markdown source" : "Reading mode")
            Spacer()
            saveStateLabel
        }
        .font(.caption2)
        .foregroundStyle(theme.secondaryTextColor)
        .padding(.horizontal, 12)
        .frame(height: 27)
        .background(theme.surfaceColor)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var saveStateLabel: some View {
        switch session.saveState {
        case .idle:
            Text(session.url.lastPathComponent)
        case .pending:
            Label("Waiting to save", systemImage: "ellipsis")
        case .saving:
            Label("Saving", systemImage: "arrow.triangle.2.circlepath")
        case .saved:
            Label("Saved", systemImage: "checkmark")
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
                .lineLimit(1)
        case .conflict:
            Label("Conflict", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        }
    }
}
