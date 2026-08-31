import SwiftUI

extension Notification.Name {
    static let plainleafFocusWorkspaceSearch = Notification.Name("Plainleaf.Workspace.FocusSearch")
    static let plainleafResignWorkspaceSearch = Notification.Name("Plainleaf.Workspace.ResignSearch")
}

struct WorkspaceSearchField: View {
    @ObservedObject var model: AppModel
    let theme: PlainleafTheme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isFocused ? theme.accentColor : theme.secondaryTextColor)

            TextField("Search notes", text: $model.workspaceSearchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isFocused)
                .onSubmit(openFirstResult)
                .accessibilityLabel("Search workspace Markdown")

            if model.workspaceSearchQuery.isEmpty {
                Text("⇧⌘F")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.secondaryTextColor.opacity(0.72))
                    .accessibilityHidden(true)
            } else {
                Button {
                    model.clearWorkspaceSearch()
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.secondaryTextColor)
                .help("Clear workspace search")
                .accessibilityLabel("Clear workspace search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 31)
        .background(theme.codeBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(
                    isFocused ? theme.accentColor.opacity(0.78) : theme.borderColor.opacity(0.78),
                    lineWidth: 1
                )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
        .onReceive(NotificationCenter.default.publisher(for: .plainleafFocusWorkspaceSearch)) { _ in
            isFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .plainleafResignWorkspaceSearch)) { _ in
            isFocused = false
        }
        .task {
            await Task.yield()
            if model.workspaceSearchQuery.isEmpty {
                isFocused = false
            }
        }
        .onExitCommand {
            model.clearWorkspaceSearch()
            isFocused = false
        }
    }

    private func openFirstResult() {
        guard let result = model.workspaceSearchResponse.results.first else { return }
        model.openSearchResult(result, match: result.matches.first)
    }
}

struct WorkspaceSearchResultsView: View {
    @ObservedObject var model: AppModel
    let theme: PlainleafTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            resultSummary

            if model.isSearchingWorkspace && model.workspaceSearchResponse.results.isEmpty {
                searchStatus(icon: nil, title: "Searching notes…", detail: nil) {
                    ProgressView().controlSize(.small)
                }
            } else if model.workspaceSearchResponse.results.isEmpty {
                searchStatus(
                    icon: "text.magnifyingglass",
                    title: "No matching notes",
                    detail: "Try a shorter phrase or check the spelling."
                ) { EmptyView() }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.workspaceSearchResponse.results) { result in
                            searchResult(result)
                            Divider().overlay(theme.borderColor.opacity(0.58))
                        }

                        if model.workspaceSearchResponse.totalResultCount > model.workspaceSearchResponse.results.count {
                            Text("Showing the first \(model.workspaceSearchResponse.results.count) notes")
                                .font(.system(size: 10.5))
                                .foregroundStyle(theme.secondaryTextColor)
                                .padding(12)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultSummary: some View {
        HStack(spacing: 7) {
            if model.isSearchingWorkspace {
                ProgressView().controlSize(.mini)
            }
            Text(summaryText)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .tracking(0.7)
            Spacer()
            if model.workspaceSearchResponse.unreadableFileCount > 0 {
                Text("\(model.workspaceSearchResponse.unreadableFileCount) SKIPPED")
                    .help("Some Markdown files could not be read as UTF-8")
            }
        }
        .foregroundStyle(theme.secondaryTextColor)
        .padding(.horizontal, 16)
        .frame(height: 31)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.borderColor.opacity(0.58)).frame(height: 1)
        }
    }

    private var summaryText: String {
        let count = model.workspaceSearchResponse.totalResultCount
        return count == 1 ? "1 NOTE FOUND" : "\(count) NOTES FOUND"
    }

    private func searchResult(_ result: WorkspaceSearchResult) -> some View {
        let selected = model.document?.url.standardizedFileURL == result.file.url.standardizedFileURL
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                model.openSearchResult(result, match: nil)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(selected ? theme.accentColor : theme.borderColor)
                        .frame(width: 3, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.displayName)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(theme.textColor)
                            .lineLimit(1)
                        Text(result.file.relativePath)
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(theme.secondaryTextColor)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 5)
                    Text(result.occurrenceCount > 0 ? "\(result.occurrenceCount)" : "PATH")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(result.pathMatched ? theme.accentColor : theme.secondaryTextColor)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(result.file.relativePath)")

            ForEach(result.matches) { match in
                Button {
                    model.openSearchResult(result, match: match)
                } label: {
                    HStack(alignment: .top, spacing: 7) {
                        Text("L\(match.lineNumber)")
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryTextColor)
                            .frame(width: 29, alignment: .trailing)
                        highlighted(match.excerpt)
                            .font(.system(size: 11.5))
                            .foregroundStyle(theme.secondaryTextColor)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open line \(match.lineNumber) in \(result.displayName): \(match.excerpt)")
            }

            if result.matches.isEmpty, result.pathMatched {
                Text("File path match")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.secondaryTextColor)
                    .padding(.leading, 49)
                    .padding(.bottom, 9)
            } else {
                Color.clear.frame(height: 4)
            }
        }
        .background(selected ? theme.selectionColor.opacity(0.42) : Color.clear)
    }

    private func highlighted(_ value: String) -> Text {
        let query = model.workspaceSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let range = value.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
              ) else {
            return Text(value)
        }
        return Text(String(value[..<range.lowerBound]))
            + Text(String(value[range])).bold().foregroundColor(theme.accentColor)
            + Text(String(value[range.upperBound...]))
    }

    @ViewBuilder
    private func searchStatus<Accessory: View>(
        icon: String?,
        title: String,
        detail: String?,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(theme.secondaryTextColor)
            }
            accessory()
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
            if let detail {
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 38)
    }
}
