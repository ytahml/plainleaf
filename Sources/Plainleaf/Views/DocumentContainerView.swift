import SwiftUI

struct DocumentContainerView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var session: DocumentSession
    let theme: PlainleafTheme
    @State private var showsReadingAppearance = false

    var body: some View {
        VStack(spacing: 0) {
            documentHeader

            if session.hasConflict {
                conflictBanner
            }

            Group {
                switch model.mode {
                case .source:
                    sourceSurface
                case .split:
                    splitSurface
                case .reading:
                    reader(syncEnabled: false)
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
                    .font(Font(PlainleafTypography.readingFont(size: 19, weight: .semibold)))
                    .lineLimit(1)
            }

            Spacer(minLength: 20)

            if model.mode != .source {
                readingAppearanceButton
            }

            ModeSwitch(model: model, theme: theme)
        }
        .padding(.horizontal, 22)
        .frame(height: 66)
        .background(theme.chromeColor)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.borderColor.opacity(0.8)).frame(height: 1)
        }
    }

    private var sourceSurface: some View {
        ZStack {
            theme.canvasColor
            sourceEditor(syncEnabled: false, compactLayout: false)
                .frame(maxWidth: 860)
                .background(theme.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.borderColor.opacity(theme.isDark ? 0.58 : 0.72), lineWidth: 1)
                }
                .shadow(color: .black.opacity(theme.isDark ? 0.16 : 0.055), radius: 12, y: 5)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
    }

    private var splitSurface: some View {
        HSplitView {
            splitPane(title: "MARKDOWN SOURCE", symbol: "chevron.left.forwardslash.chevron.right") {
                sourceEditor(syncEnabled: true, compactLayout: true)
            }
            .frame(minWidth: 250, idealWidth: 420, maxWidth: .infinity)

            splitPane(title: "HTML PREVIEW", symbol: "book.pages") {
                reader(syncEnabled: true)
            }
            .frame(minWidth: 270, idealWidth: 440, maxWidth: .infinity)
        }
        .background(theme.canvasColor)
        .accessibilityLabel("Synchronized source and HTML preview")
    }

    private func sourceEditor(syncEnabled: Bool, compactLayout: Bool) -> some View {
        SourceEditor(
            text: $session.text,
            theme: theme,
            revealRequest: model.sourceRevealRequest?.documentURL.standardizedFileURL == session.url.standardizedFileURL
                ? model.sourceRevealRequest
                : nil,
            documentURL: session.url,
            scrollSync: model.previewScrollSync,
            syncEnabled: syncEnabled,
            compactLayout: compactLayout
        )
    }

    private func reader(syncEnabled: Bool) -> some View {
        MarkdownReaderView(
            source: session.text,
            documentURL: session.url,
            workspaceURL: session.workspaceURL,
            theme: theme,
            appearance: model.readingAppearance,
            onOpenLink: model.openLink,
            onActiveHeadingChange: { [weak model, documentURL = session.url] anchor in
                model?.updateActiveHeading(anchor, for: documentURL)
            },
            scrollSync: model.previewScrollSync,
            syncEnabled: syncEnabled
        )
    }

    private var readingAppearanceButton: some View {
        Button {
            showsReadingAppearance.toggle()
        } label: {
            Image(systemName: "textformat.size")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 27, height: 25)
                .background(showsReadingAppearance ? theme.selectionColor : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(showsReadingAppearance ? theme.accentColor : theme.secondaryTextColor)
        .help("Adjust reading typography")
        .accessibilityLabel("Reading appearance")
        .popover(isPresented: $showsReadingAppearance, arrowEdge: .bottom) {
            ReadingAppearancePanel(model: model, theme: theme)
        }
    }

    private func splitPane<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.accentColor)
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.9)
                Spacer()
                Image(systemName: "arrow.up.and.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.secondaryTextColor.opacity(0.75))
                    .help("Scroll position is synchronized")
            }
            .foregroundStyle(theme.secondaryTextColor)
            .padding(.horizontal, 12)
            .frame(height: 31)
            .background(theme.chromeColor)
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.borderColor.opacity(0.72)).frame(height: 1)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.surfaceColor)
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
        .background(theme.chromeColor)
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

private struct ReadingAppearancePanel: View {
    @ObservedObject var model: AppModel
    let theme: PlainleafTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            specimen

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("TEXT SIZE")
                HStack(spacing: 10) {
                    Button { model.adjustReadingTextSize(by: -ReadingAppearance.textSizeStep) } label: {
                        Image(systemName: "minus")
                            .frame(width: 24, height: 20)
                    }
                    .disabled(!model.readingAppearance.canDecreaseTextSize)
                    .accessibilityLabel("Decrease reading text size")

                    Text(model.readingAppearance.textSize.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Reading text size")
                        .accessibilityValue(model.readingAppearance.textSize.formatted())

                    Button { model.adjustReadingTextSize(by: ReadingAppearance.textSizeStep) } label: {
                        Image(systemName: "plus")
                            .frame(width: 24, height: 20)
                    }
                    .disabled(!model.readingAppearance.canIncreaseTextSize)
                    .accessibilityLabel("Increase reading text size")
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("LINE SPACING")
                Picker("Line spacing", selection: leadingBinding) {
                    ForEach(ReadingLeading.allCases) { leading in
                        Text(leading.label).tag(leading)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("PAGE WIDTH")
                Picker("Page width", selection: measureBinding) {
                    ForEach(ReadingMeasure.allCases) { measure in
                        Text(measure.label).tag(measure)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Text("Used in Split and Read.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.secondaryTextColor)
                Spacer()
                Button("Reset") { model.resetReadingAppearance() }
                    .disabled(model.readingAppearance.isStandard)
            }
        }
        .padding(18)
        .frame(width: 330)
        .background(theme.chromeColor)
    }

    private var specimen: some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            Text("Aa 文章")
                .font(Font(PlainleafTypography.readingFont(
                    size: model.readingAppearance.textSize + 8,
                    weight: .medium
                )))
                .foregroundStyle(theme.textColor)
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("READING SET")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.1)
                Text("New York · Songti")
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(theme.secondaryTextColor)
        }
        .padding(.horizontal, 13)
        .frame(height: 64)
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(theme.borderColor.opacity(0.8), lineWidth: 1)
        }
    }

    private func settingLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(theme.secondaryTextColor)
    }

    private var leadingBinding: Binding<ReadingLeading> {
        Binding(
            get: { model.readingAppearance.leading },
            set: { model.setReadingLeading($0) }
        )
    }

    private var measureBinding: Binding<ReadingMeasure> {
        Binding(
            get: { model.readingAppearance.measure },
            set: { model.setReadingMeasure($0) }
        )
    }
}

private struct ModeSwitch: View {
    @ObservedObject var model: AppModel
    let theme: PlainleafTheme

    var body: some View {
        HStack(spacing: 2) {
            modeButton(.source, label: "Write", symbol: "pencil.line")
            modeButton(.split, label: "Split", symbol: "rectangle.split.2x1")
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
            if !isSelected { model.setMode(mode) }
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
        .accessibilityLabel(accessibilityLabel(for: mode))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accessibilityLabel(for mode: ReadingMode) -> String {
        switch mode {
        case .source: "Show source editor"
        case .split: "Show synchronized source and preview"
        case .reading: "Show reading mode"
        }
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
