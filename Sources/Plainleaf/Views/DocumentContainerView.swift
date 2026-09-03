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
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.url.deletingPathExtension().lastPathComponent)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Text(relativeLocation)
                    .font(.system(size: 10.5, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 20)

            if model.mode != .source {
                readingAppearanceButton
            }

            ModeSwitch(model: model, theme: theme)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.borderColor.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: Color(nsColor: theme.text).opacity(theme.isDark ? 0.12 : 0.045), radius: 12, y: 4)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var sourceSurface: some View {
        ZStack {
            theme.canvasColor
            sourceEditor(syncEnabled: false, compactLayout: false)
                .frame(maxWidth: 920)
                .background(theme.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.borderColor.opacity(0.72), lineWidth: 1)
                }
                .shadow(color: Color(nsColor: theme.text).opacity(theme.isDark ? 0.14 : 0.05), radius: 18, y: 7)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
        }
    }

    private var splitSurface: some View {
        HSplitView {
            splitPane(title: "Source", symbol: "chevron.left.forwardslash.chevron.right") {
                sourceEditor(syncEnabled: true, compactLayout: true)
            }
            .frame(minWidth: 250, idealWidth: 420, maxWidth: .infinity)

            splitPane(title: "Preview", symbol: "book.pages") {
                reader(syncEnabled: true)
            }
            .frame(minWidth: 270, idealWidth: 440, maxWidth: .infinity)
        }
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.borderColor.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: Color(nsColor: theme.text).opacity(theme.isDark ? 0.14 : 0.05), radius: 18, y: 7)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
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
                .frame(width: 30, height: 30)
                .background(showsReadingAppearance ? theme.selectionColor : theme.codeBackgroundColor.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
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
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.accentColor)
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(theme.secondaryTextColor)
            .padding(.horizontal, 14)
            .frame(height: 38)
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
            Button("Use disk version") { session.resolveUsingDiskVersion() }
            Button("Keep my version") { session.resolveKeepingLocalVersion() }
                .buttonStyle(.borderedProminent)
                .tint(theme.warmAccentColor)
        }
        .padding(12)
        .background(theme.warmAccentColor.opacity(theme.isDark ? 0.14 : 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.warmAccentColor.opacity(0.32), lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Text("\(session.text.count.formatted()) characters")
            Text("UTF-8")
            Spacer()
            saveStateLabel
        }
        .font(.system(size: 10.5, weight: .medium, design: .rounded))
        .foregroundStyle(theme.secondaryTextColor)
        .padding(.horizontal, 18)
        .frame(height: 30)
        .background(theme.canvasColor)
    }

    @ViewBuilder
    private var saveStateLabel: some View {
        switch session.saveState {
        case .idle:
            Label("On disk", systemImage: "checkmark.circle.fill")
                .labelStyle(SaveStateLabelStyle(color: theme.accentColor))
        case .pending:
            Label("Waiting to save", systemImage: "clock")
                .labelStyle(SaveStateLabelStyle(color: theme.warmAccentColor))
        case .saving:
            Label("Saving", systemImage: "arrow.triangle.2.circlepath")
                .labelStyle(SaveStateLabelStyle(color: theme.warmAccentColor))
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
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
        VStack(alignment: .leading, spacing: 20) {
            specimen

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Text size")
                HStack(spacing: 10) {
                    Button { model.adjustReadingTextSize(by: -ReadingAppearance.textSizeStep) } label: {
                        Image(systemName: "minus")
                            .frame(width: 24, height: 20)
                    }
                    .disabled(!model.readingAppearance.canDecreaseTextSize)
                    .accessibilityLabel("Decrease reading text size")

                    Text(model.readingAppearance.textSize.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
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
                settingLabel("Line spacing")
                Picker("Line spacing", selection: leadingBinding) {
                    ForEach(ReadingLeading.allCases) { leading in
                        Text(leading.label).tag(leading)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                settingLabel("Page width")
                Picker("Page width", selection: measureBinding) {
                    ForEach(ReadingMeasure.allCases) { measure in
                        Text(measure.label).tag(measure)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Text("Used in Split and Read")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.secondaryTextColor)
                Spacer()
                Button("Reset") { model.resetReadingAppearance() }
                    .disabled(model.readingAppearance.isStandard)
            }
        }
        .padding(20)
        .frame(width: 340)
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
                Text("Reading")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("LXGW WenKai GB Lite")
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(theme.secondaryTextColor)
        }
        .padding(.horizontal, 14)
        .frame(height: 68)
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.borderColor.opacity(0.8), lineWidth: 1)
        }
    }

    private func settingLabel(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
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
        HStack(spacing: 3) {
            modeButton(.source, label: "Write", symbol: "pencil.line")
            modeButton(.split, label: "Split", symbol: "rectangle.split.2x1")
            modeButton(.reading, label: "Read", symbol: "book.pages")
        }
        .padding(3)
        .background(theme.codeBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(theme.borderColor.opacity(0.76), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func modeButton(_ mode: ReadingMode, label: String, symbol: String) -> some View {
        let isSelected = model.mode == mode
        return Button {
            if !isSelected { model.setMode(mode) }
        } label: {
            Label(label, systemImage: symbol)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(isSelected ? theme.surfaceColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(color)
            configuration.title
        }
    }
}
