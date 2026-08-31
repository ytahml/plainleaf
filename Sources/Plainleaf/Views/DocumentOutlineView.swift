import SwiftUI

struct DocumentOutlineSection: View {
    @ObservedObject var model: AppModel
    @ObservedObject var session: DocumentSession
    let theme: PlainleafTheme

    var body: some View {
        let items = DocumentOutline.build(from: session.text)
        let minimumLevel = items.map(\.level).min() ?? 1

        VStack(alignment: .leading, spacing: 0) {
            Button {
                model.showsDocumentOutline.toggle()
            } label: {
                HStack(spacing: 7) {
                    Text("ON THIS PAGE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                    Spacer(minLength: 8)
                    Text("\(items.count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                    Image(systemName: model.showsDocumentOutline ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(theme.secondaryTextColor)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: 39)
            .accessibilityLabel(model.showsDocumentOutline ? "Collapse document outline" : "Expand document outline")

            if model.showsDocumentOutline {
                if items.isEmpty {
                    Text("No headings in this note")
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.secondaryTextColor)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(items) { item in
                                    outlineButton(for: item, minimumLevel: minimumLevel)
                                        .id(item.anchor)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 10)
                        }
                        .frame(maxHeight: 218)
                        .onChange(of: model.activeHeadingAnchor) { _, anchor in
                            guard let anchor else { return }
                            proxy.scrollTo(anchor, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(theme.chromeColor)
    }

    private func outlineButton(for item: DocumentOutlineItem, minimumLevel: Int) -> some View {
        let isActive = model.activeHeadingAnchor == item.anchor
        return Button {
            model.updateActiveHeading(item.anchor, for: session.url)
            NotificationCenter.default.post(
                name: .plainleafRevealHeading,
                object: session.url,
                userInfo: ["anchor": item.anchor]
            )
        } label: {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive
                        ? theme.accentColor
                        : (item.level == 1 ? theme.accentColor.opacity(0.45) : theme.borderColor))
                    .frame(
                        width: isActive ? 4 : 3,
                        height: isActive ? 18 : (item.level == 1 ? 17 : 11)
                    )
                Text(item.title)
                    .font(.system(
                        size: item.level == 1 ? 12.5 : 11.5,
                        weight: isActive || item.level <= 2 ? .semibold : .regular
                    ))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isActive || item.level == 1 ? theme.textColor : theme.secondaryTextColor)
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isActive
                        ? theme.accentColor.opacity(theme.isDark ? 0.13 : 0.08)
                        : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .padding(.leading, CGFloat(max(0, item.level - minimumLevel)) * 10)
        .help("Heading level \(item.level): \(item.title)")
        .accessibilityLabel("Heading level \(item.level), \(item.title)")
        .accessibilityValue(isActive ? "Current section" : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
