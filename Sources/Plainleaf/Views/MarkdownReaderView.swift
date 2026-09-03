import AppKit
import SwiftUI
import WebKit

extension Notification.Name {
    static let plainleafPrint = Notification.Name("Plainleaf.Reader.Print")
    static let plainleafRevealHeading = Notification.Name("Plainleaf.Reader.RevealHeading")
}

enum HTMLPreviewNavigation {
    static func revealHeadingScript(anchor: String) -> String? {
        guard !anchor.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: anchor, options: .fragmentsAllowed),
              let encodedAnchor = String(data: data, encoding: .utf8) else {
            return nil
        }
        return "document.getElementById(\(encodedAnchor))?.scrollIntoView({block: 'start'});"
    }

    static func localFragmentAnchor(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "about" else { return nil }
        if let fragment = url.fragment, !fragment.isEmpty {
            return fragment.removingPercentEncoding ?? fragment
        }
        let decoded = url.absoluteString.removingPercentEncoding ?? url.absoluteString
        let prefix = "about:blank#"
        guard decoded.hasPrefix(prefix) else { return nil }
        let anchor = String(decoded.dropFirst(prefix.count))
        return anchor.isEmpty ? nil : anchor
    }

    static func revealLocalFragmentScript(anchor: String) -> String? {
        guard !anchor.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: anchor, options: .fragmentsAllowed),
              let encodedAnchor = String(data: data, encoding: .utf8) else {
            return nil
        }
        return """
        (() => {
          const anchor = \(encodedAnchor);
          const target = document.getElementById(anchor);
          if (!target) return false;
          history.replaceState(null, '', '#' + encodeURIComponent(anchor));
          target.setAttribute('tabindex', '-1');
          target.scrollIntoView({block: 'center'});
          target.focus({preventScroll: true});
          return true;
        })()
        """
    }

    static let scrollSnapshotScript = """
    (() => {
      const maximum = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
      const progress = Math.max(0, Math.min(1, window.scrollY / maximum));
      const headings = Array.from(
        document.querySelectorAll('h1[id], h2[id], h3[id], h4[id], h5[id], h6[id]')
      ).filter(heading => !heading.closest('.footnotes'));
      if (headings.length === 0) return { progress, anchor: null };
      const threshold = Math.min(160, Math.max(64, window.innerHeight * 0.22));
      let active = headings[0];
      for (const heading of headings) {
        if (heading.getBoundingClientRect().top <= threshold) active = heading;
        else break;
      }
      if (window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 2) {
        active = headings[headings.length - 1];
      }
      return { progress, anchor: active.id };
    })()
    """
}

struct HTMLPreviewScrollSnapshot: Equatable {
    let progress: Double
    let activeHeadingAnchor: String?

    init?(javascriptValue: Any?) {
        guard let values = javascriptValue as? [String: Any],
              let progress = (values["progress"] as? NSNumber)?.doubleValue else {
            return nil
        }
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
        if let anchor = values["anchor"] as? String, !anchor.isEmpty {
            self.activeHeadingAnchor = anchor
        } else {
            self.activeHeadingAnchor = nil
        }
    }
}

struct MarkdownReaderView: View {
    let source: String
    let documentURL: URL
    let workspaceURL: URL
    let theme: PlainleafTheme
    let appearance: ReadingAppearance
    let onOpenLink: (String) -> Void
    let onActiveHeadingChange: (String?) -> Void
    @ObservedObject var scrollSync: PreviewScrollSyncController
    let syncEnabled: Bool

    var body: some View {
        HTMLPreviewWebView(
            source: source,
            documentURL: documentURL,
            workspaceURL: workspaceURL,
            theme: theme,
            appearance: appearance,
            onOpenLink: onOpenLink,
            onActiveHeadingChange: onActiveHeadingChange,
            scrollSync: scrollSync,
            syncEnabled: syncEnabled
        )
        .background(theme.canvasColor)
        .accessibilityLabel("Rendered Markdown document")
    }
}

private struct HTMLPreviewWebView: NSViewRepresentable {
    let source: String
    let documentURL: URL
    let workspaceURL: URL
    let theme: PlainleafTheme
    let appearance: ReadingAppearance
    let onOpenLink: (String) -> Void
    let onActiveHeadingChange: (String?) -> Void
    @ObservedObject var scrollSync: PreviewScrollSyncController
    let syncEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onOpenLink: onOpenLink,
            onActiveHeadingChange: onActiveHeadingChange,
            scrollSync: scrollSync,
            syncEnabled: syncEnabled
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.startScrollPolling()
        webView.allowsMagnification = true
        webView.underPageBackgroundColor = theme.canvas
        webView.setAccessibilityLabel("Rendered Markdown document")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onOpenLink = onOpenLink
        context.coordinator.onActiveHeadingChange = onActiveHeadingChange
        context.coordinator.scrollSync = scrollSync
        context.coordinator.syncEnabled = syncEnabled
        webView.underPageBackgroundColor = theme.canvas

        var renderer = HTMLDocumentRenderer(
            documentURL: documentURL,
            workspaceURL: workspaceURL,
            theme: theme,
            appearance: appearance
        )
        let html = renderer.render(source)
        if context.coordinator.loadedHTML != html {
            context.coordinator.isReloadingContent = true
            let shouldPreserveScroll = context.coordinator.loadedDocumentURL == documentURL
            if !shouldPreserveScroll {
                context.coordinator.lastObservedProgress = nil
                context.coordinator.lastObservedHeadingAnchor = nil
                context.coordinator.hasObservedHeadingAnchor = false
            }
            context.coordinator.loadedHTML = html
            context.coordinator.loadedDocumentURL = documentURL
            if shouldPreserveScroll {
                let coordinator = context.coordinator
                webView.evaluateJavaScript("window.scrollY") { value, _ in
                    guard coordinator.loadedHTML == html,
                          coordinator.loadedDocumentURL == documentURL else { return }
                    coordinator.pendingScrollOffset = (value as? NSNumber)?.doubleValue ?? 0
                    webView.loadHTMLString(html, baseURL: PlainleafTypography.bundledFontBaseURL)
                }
            } else {
                context.coordinator.pendingScrollOffset = 0
                webView.loadHTMLString(html, baseURL: PlainleafTypography.bundledFontBaseURL)
            }
        }
        context.coordinator.applySynchronizedScrollIfNeeded()
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        coordinator.stopScrollPolling()
        webView.navigationDelegate = nil
        if coordinator.webView === webView {
            coordinator.webView = nil
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var onOpenLink: (String) -> Void
        var onActiveHeadingChange: (String?) -> Void
        var scrollSync: PreviewScrollSyncController
        var syncEnabled: Bool
        weak var webView: WKWebView?
        var loadedHTML: String?
        var loadedDocumentURL: URL?
        var pendingScrollOffset: Double = 0
        var activePrintOperation: NSPrintOperation?
        var lastAppliedScrollRevision = -1
        var isApplyingSynchronizedScroll = false
        var isReloadingContent = false
        var lastProgrammaticProgress: Double?
        var lastObservedProgress: Double?
        var lastObservedHeadingAnchor: String?
        var hasObservedHeadingAnchor = false
        var scrollPollTimer: Timer?
        var isPollingScroll = false

        init(
            onOpenLink: @escaping (String) -> Void,
            onActiveHeadingChange: @escaping (String?) -> Void,
            scrollSync: PreviewScrollSyncController,
            syncEnabled: Bool
        ) {
            self.onOpenLink = onOpenLink
            self.onActiveHeadingChange = onActiveHeadingChange
            self.scrollSync = scrollSync
            self.syncEnabled = syncEnabled
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(printRequested),
                name: .plainleafPrint,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(revealHeading(_:)),
                name: .plainleafRevealHeading,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(navigationAction.navigationType == .other ? .allow : .cancel)
                return
            }

            if navigationAction.navigationType == .linkActivated {
                if url.scheme == "plainleaf", let destination = destination(from: url) {
                    onOpenLink(destination)
                    decisionHandler(.cancel)
                    return
                }
                if let anchor = HTMLPreviewNavigation.localFragmentAnchor(from: url),
                   let script = HTMLPreviewNavigation.revealLocalFragmentScript(anchor: anchor) {
                    webView.evaluateJavaScript(script)
                    decisionHandler(.cancel)
                    return
                }
                decisionHandler(.cancel)
                return
            }

            // `loadHTMLString` uses an internal WebKit URL whose scheme is not
            // API-stable. The document is fully generated by Plainleaf, has a
            // restrictive CSP, and runs with JavaScript disabled, so permit its
            // non-user-initiated main-frame load. Every activated link remains
            // handled by the explicit branch above.
            decisionHandler(navigationAction.navigationType == .other ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if pendingScrollOffset > 0 {
                let offset = pendingScrollOffset
                pendingScrollOffset = 0
                isApplyingSynchronizedScroll = true
                webView.evaluateJavaScript("window.scrollTo(0, \(offset))") { [weak self] _, _ in
                    Task { @MainActor in
                        await Task.yield()
                        self?.isApplyingSynchronizedScroll = false
                        self?.isReloadingContent = false
                        self?.applySynchronizedScrollIfNeeded()
                    }
                }
            } else {
                scheduleStoredScrollPosition()
            }
        }

        func startScrollPolling() {
            guard scrollPollTimer == nil else { return }
            let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(pollScrollProgress), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            scrollPollTimer = timer
        }

        func stopScrollPolling() {
            scrollPollTimer?.invalidate()
            scrollPollTimer = nil
            isPollingScroll = false
        }

        @objc private func pollScrollProgress() {
            guard let webView,
                  !isPollingScroll,
                  !isApplyingSynchronizedScroll,
                  !isReloadingContent else {
                return
            }
            isPollingScroll = true
            webView.evaluateJavaScript(HTMLPreviewNavigation.scrollSnapshotScript) { [weak self] value, _ in
                guard let self else { return }
                self.isPollingScroll = false
                guard let snapshot = HTMLPreviewScrollSnapshot(javascriptValue: value) else { return }
                if !self.hasObservedHeadingAnchor ||
                    self.lastObservedHeadingAnchor != snapshot.activeHeadingAnchor {
                    self.hasObservedHeadingAnchor = true
                    self.lastObservedHeadingAnchor = snapshot.activeHeadingAnchor
                    self.onActiveHeadingChange(snapshot.activeHeadingAnchor)
                }
                let progress = snapshot.progress
                if let lastProgrammaticProgress,
                   abs(lastProgrammaticProgress - progress) < 0.002 {
                    self.lastProgrammaticProgress = nil
                    self.lastObservedProgress = progress
                    return
                }
                self.lastProgrammaticProgress = nil
                guard self.lastObservedProgress.map({ abs($0 - progress) >= 0.002 }) ?? true else {
                    return
                }
                self.lastObservedProgress = progress
                self.scrollSync.record(progress, from: .preview, synchronize: self.syncEnabled)
            }
        }

        func applySynchronizedScrollIfNeeded() {
            let update = scrollSync.update
            guard syncEnabled,
                  !isReloadingContent,
                  update.origin == .source,
                  update.revision != lastAppliedScrollRevision else {
                return
            }
            lastAppliedScrollRevision = update.revision
            applyScrollProgress(update.progress)
        }

        func scheduleStoredScrollPosition() {
            let progress = scrollSync.progress(for: .preview)
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.applyScrollProgress(progress)
                await Task.yield()
                self?.isReloadingContent = false
                self?.applySynchronizedScrollIfNeeded()
            }
        }

        @objc private func printRequested() {
            guard let webView, activePrintOperation == nil else { return }
            let info = NSPrintInfo.shared.copy() as! NSPrintInfo
            info.horizontalPagination = .fit
            info.verticalPagination = .automatic
            info.isHorizontallyCentered = true
            let operation = webView.printOperation(with: info)
            operation.showsPrintPanel = true
            operation.showsProgressPanel = true
            guard let window = webView.window else {
                operation.run()
                return
            }
            activePrintOperation = operation
            operation.runModal(
                for: window,
                delegate: self,
                didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        }

        @objc private func revealHeading(_ notification: Notification) {
            guard let webView,
                  let requestedURL = notification.object as? URL,
                  requestedURL.standardizedFileURL == loadedDocumentURL?.standardizedFileURL,
                  let anchor = notification.userInfo?["anchor"] as? String,
                  let script = HTMLPreviewNavigation.revealHeadingScript(anchor: anchor) else {
                return
            }
            webView.evaluateJavaScript(script)
        }

        @objc private func printOperationDidRun(
            _ operation: NSPrintOperation,
            success: Bool,
            contextInfo: UnsafeMutableRawPointer?
        ) {
            activePrintOperation = nil
        }

        private func destination(from url: URL) -> String? {
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "destination" })?
                .value
        }

        private func applyScrollProgress(_ progress: Double) {
            guard let webView else { return }
            let normalized = min(max(progress, 0), 1)
            isApplyingSynchronizedScroll = true
            lastProgrammaticProgress = normalized
            webView.evaluateJavaScript(
                "window.scrollTo(0, Math.max(0, document.documentElement.scrollHeight - window.innerHeight) * \(normalized))"
            ) { [weak self] _, _ in
                Task { @MainActor in
                    await Task.yield()
                    self?.lastObservedProgress = normalized
                    self?.isApplyingSynchronizedScroll = false
                }
            }
        }
    }
}
