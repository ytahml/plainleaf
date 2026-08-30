import AppKit
import SwiftUI

extension Notification.Name {
    static let plainleafBold = Notification.Name("Plainleaf.Editor.Bold")
    static let plainleafItalic = Notification.Name("Plainleaf.Editor.Italic")
    static let plainleafLink = Notification.Name("Plainleaf.Editor.Link")
    static let plainleafInlineCode = Notification.Name("Plainleaf.Editor.InlineCode")
}

struct SourceEditor: NSViewRepresentable {
    @Binding var text: String
    let theme: PlainleafTheme

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.surface

        let textView = NSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.textContainerInset = NSSize(width: 56, height: 48)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.string = text
        textView.setAccessibilityLabel("Markdown source editor")

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.applyHighlighting(theme: theme)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selection = textView.selectedRange()
            context.coordinator.isApplyingAttributes = true
            textView.string = text
            textView.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
            context.coordinator.isApplyingAttributes = false
        }
        scrollView.backgroundColor = theme.surface
        context.coordinator.applyHighlighting(theme: theme)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceEditor
        weak var textView: NSTextView?
        var isApplyingAttributes = false

        init(parent: SourceEditor) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(bold), name: .plainleafBold, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(italic), name: .plainleafItalic, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(link), name: .plainleafLink, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(inlineCode), name: .plainleafInlineCode, object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingAttributes, let textView else { return }
            parent.text = textView.string
            applyHighlighting(theme: parent.theme)
        }

        func applyHighlighting(theme: PlainleafTheme) {
            guard let textView, let storage = textView.textStorage else { return }
            let string = storage.string
            let fullRange = NSRange(location: 0, length: (string as NSString).length)
            let selection = textView.selectedRanges
            let baseFont = NSFont.monospacedSystemFont(ofSize: 15.5, weight: .regular)
            let emphasisFont = NSFont.monospacedSystemFont(ofSize: 15.5, weight: .semibold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 5.5
            paragraph.paragraphSpacing = 1

            isApplyingAttributes = true
            storage.beginEditing()
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: theme.text,
                .backgroundColor: theme.surface,
                .paragraphStyle: paragraph
            ], range: fullRange)

            apply(pattern: #"(?m)^(#{1,6})(\s+.*)$"#, color: theme.accent, font: emphasisFont, to: storage)
            apply(pattern: #"(?m)^\s*>.*$"#, color: theme.warmAccent, font: nil, to: storage)
            apply(pattern: #"(?m)^\s*(?:[-+*]|\d+\.)\s+"#, color: theme.accent, font: nil, to: storage)
            apply(pattern: #"(?s)```.*?```"#, color: theme.text, font: baseFont, background: theme.codeBackground, to: storage)
            apply(pattern: #"`[^`\n]+`"#, color: theme.accent, font: baseFont, background: theme.codeBackground, to: storage)
            apply(pattern: #"\*\*[^\n]+?\*\*|__[^\n]+?__"#, color: theme.text, font: emphasisFont, to: storage)
            apply(pattern: #"\[[^\]]+\]\([^\)]+\)"#, color: theme.accent, font: nil, to: storage)
            apply(pattern: #"(?m)^\s*[-*]\s+\[[ xX]\]\s+"#, color: theme.accent, font: nil, to: storage)

            storage.endEditing()
            textView.selectedRanges = selection
            textView.backgroundColor = theme.surface
            textView.insertionPointColor = theme.accent
            textView.selectedTextAttributes = [
                .backgroundColor: theme.selection,
                .foregroundColor: theme.text
            ]
            textView.typingAttributes = [
                .font: baseFont,
                .foregroundColor: theme.text,
                .backgroundColor: theme.surface,
                .paragraphStyle: paragraph
            ]
            isApplyingAttributes = false
        }

        @objc private func bold() { wrap(prefix: "**", suffix: "**", placeholder: "bold text") }
        @objc private func italic() { wrap(prefix: "*", suffix: "*", placeholder: "italic text") }
        @objc private func inlineCode() { wrap(prefix: "`", suffix: "`", placeholder: "code") }
        @objc private func link() { wrap(prefix: "[", suffix: "](https://)", placeholder: "link text") }

        private func wrap(prefix: String, suffix: String, placeholder: String) {
            guard let textView,
                  textView.window?.firstResponder === textView else { return }
            let selectedRange = textView.selectedRange()
            let nsString = textView.string as NSString
            let selected = selectedRange.length > 0 ? nsString.substring(with: selectedRange) : placeholder
            let replacement = prefix + selected + suffix
            guard textView.shouldChangeText(in: selectedRange, replacementString: replacement) else { return }
            textView.textStorage?.replaceCharacters(in: selectedRange, with: replacement)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: selectedRange.location + prefix.count, length: selected.utf16.count))
        }

        private func apply(
            pattern: String,
            color: NSColor,
            font: NSFont?,
            background: NSColor? = nil,
            to storage: NSTextStorage
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let range = NSRange(location: 0, length: (storage.string as NSString).length)
            regex.enumerateMatches(in: storage.string, range: range) { match, _, _ in
                guard let match else { return }
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
                if let font { storage.addAttribute(.font, value: font, range: match.range) }
                if let background { storage.addAttribute(.backgroundColor, value: background, range: match.range) }
            }
        }
    }
}
