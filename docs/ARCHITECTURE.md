# Architecture

## Layers

- `AppModel`: window-level orchestration, workspace lifecycle, selection, mode, theme, and commands.
- `WorkspaceStore`: sandbox authorization and read-only tree enumeration.
- `WorkspaceSearch`: cancellable background UTF-8 reads plus a pure path/content matching, ranking, and snippet engine.
- `DocumentSession`: loaded text, autosave scheduling, disk revision fingerprints, and conflict state.
- `SourceEditor`: AppKit `NSTextView` bridge with native editing behavior, lightweight Markdown source highlighting, and non-mutating search-result reveal requests.
- `MarkdownRenderer`: `swift-markdown` AST conversion into Plainleaf-owned render nodes.
- `DocumentOutline`: heading extraction with the same duplicate-safe anchor generator used by HTML output.
- `PreviewScrollSyncController`: document-scoped normalized source/preview positions and origin-tagged updates that prevent feedback loops.
- `ReadingAppearance`: bounded text size plus named leading and page-measure presets, with isolated application-default persistence.
- `HTMLDocumentRenderer`: controlled render nodes to a complete semantic HTML document with Plainleaf-owned CSS.
- `StandaloneHTMLExport`: one-call standalone rendering, UTF-8 encoding, suggested naming, and atomic destination writing.
- `DocumentOutlineView`: collapsible sidebar index with heading hierarchy and accessible navigation controls.
- `WorkspaceSearchView`: focused sidebar search field, result/empty/loading states, and accessible line-level navigation.
- `MarkdownReaderView`: a JavaScript-disabled `WKWebView` bridge for preview, link routing, scroll preservation, split synchronization, outline jumps and active-section tracking, and printing.

The preview does not execute Markdown raw HTML. Raw blocks and inline HTML are escaped and shown as source text. A restrictive content security policy rejects scripts, connections, frames, forms, and arbitrary resource origins. Verified local raster images inside the authorized workspace are embedded as data URLs; remote images, unavailable files, workspace-escaping symlinks, and SVG are rendered as placeholders.

`swift-markdown` 0.8.x does not expose footnote nodes, so `MarkdownRenderer` owns a narrow preprocessing extension. It extracts unique root-level `[^label]:` definitions outside fenced code, keeps indented continuation blocks, protects escaped `\[^label]` syntax, and then passes the remaining source and definition bodies through the normal controlled AST conversion. A source-range pass over `ListItem` nodes prevents one-to-three-space list content from being mistaken for a root definition while preserving the same indentation allowance at the document root. References are recognized only in plain inline text outside links and code. Numbering follows first reference order; undefined references remain literal; unreferenced definitions are omitted from the preview. `RenderedDocument` carries typed references and parsed footnote blocks rather than raw HTML.

The sandboxed app declares outgoing-client capability because macOS WebKit requires it to launch its isolated WebContent and Networking helper processes. Plainleaf does not use that capability as a product network feature: the generated document contains no remote resources, JavaScript is disabled, the CSP sets `connect-src 'none'`, and activated links are intercepted before WebKit navigation. Web URLs are handed to the system browser only after an explicit user click.

`HighlighterSwift` 3.1.0 is vendored with its upstream license. Plainleaf changes only its resource lookup order so a packaged app loads the library bundle from `Contents/Resources`; development builds still fall back to SwiftPM's `Bundle.module`.

The HTML preview is still local application UI, not standalone HTML export. User Markdown remains the only document source of truth.

`HTMLDocumentRenderer` has two render purposes behind the same interface. Preview mode routes document links through the native `plainleaf://open` bridge. Standalone mode emits a titled, no-referrer document, keeps page fragments and relative or explicit HTTP/HTTPS/mail links, and replaces executable, file, data, protocol-relative, absolute-path, control-character, and unknown schemes with visibly blocked text. Both purposes share the same semantic nodes, CSS, embedded-image checks, code highlighter, footnotes, print rules, CSP, and heading generator. The generator resets for every render so reusing a renderer cannot drift duplicate anchors.

`StandaloneHTMLExport` is the concrete file module rather than an abstraction seam: it invokes standalone rendering once, owns UTF-8 bytes and the suggested filename, and exposes one atomic `write(to:)` operation. `AppModel` remains the AppKit adapter that presents `NSSavePanel`; it exports the current in-memory document without first mutating or saving the Markdown source.

Reading appearance is modeled as data rather than user-authored CSS. `AppModel` restores and persists only three bounded values in application defaults. `HTMLDocumentRenderer` serializes those values into Plainleaf-owned CSS custom properties for body size, leading, and paper width; the existing HTML, CSP, font stack, and print stylesheet remain controlled by the app. Changing a value regenerates the same local document and uses the existing same-document scroll-preservation path. The control is shown only when Split or Read exposes an HTML surface.

The outline reparses the in-memory Markdown only while an HTML surface is visible in split or reading mode. Clicking a heading sends its generated anchor to the current document's WebView; the native bridge JSON-encodes that value before evaluating the minimal `scrollIntoView` call. The WebView's native polling bridge also returns the last heading above a viewport threshold, or the final heading at the document bottom. `AppModel` accepts that anchor only for the currently open document, and the sidebar marks it as the current section and keeps it visible. No script is embedded in the HTML, and content JavaScript remains disabled.

HTML footnotes use `doc-noteref`, `doc-endnotes`, and `doc-endnote` roles plus one back link per reference occurrence. Endnotes use `plainleaf:fn:<anchor>` and references use `plainleaf:fnref:<anchor>:<occurrence>`; the colon-delimited internal namespace cannot be emitted by the heading generator and keeps similar labels plus repeated references distinct. WebKit may expose a local `#fragment` as `about:blank%23…`; the navigation delegate recognizes only safe same-document `about` fragments, cancels navigation, JSON-encodes the anchor, then scrolls and focuses the existing DOM target through the native bridge. External and unsupported schemes remain blocked by the existing policy.

Split mode composes the existing AppKit source editor and WebKit reader in a native `HSplitView`. `SourceEditor` observes the AppKit clip view; `MarkdownReaderView` samples the Web document's normalized scroll progress and active heading together on a 100 ms native timer through one narrowly scoped `evaluateJavaScript` call. Both sides report normalized progress to `PreviewScrollSyncController`, and origin-tagged programmatic updates suppress echo loops. A synchronized report updates both panes' stored desired position before it is published, so leaving Split cannot restore a stale target cache even when the target's programmatic scroll notification was intentionally suppressed. The controller stores positions only in memory and resets for a newly opened document. This deliberately synchronizes proportional progress rather than attempting fragile Markdown-line-to-DOM mapping. Evaluating these native bridge expressions does not enable JavaScript in the loaded page: WebKit content JavaScript remains disabled and the generated document contains no scripts.

Workspace search starts from the already-filtered, non-symlink Markdown file list supplied by `WorkspaceStore`. Each query cancels its predecessor, waits through a short typing debounce, and reads files on a detached task whose cancellation is propagated explicitly. The current document's in-memory text replaces its disk copy before matching. Search results contain relative paths and source line numbers only; selecting a line issues a transient reveal request to the source editor. No index or cache is written to the workspace or application container.

## Write boundary

Plainleaf writes only:

1. A Markdown file explicitly selected or created by the user.
2. A standalone HTML destination explicitly selected by the user.
3. Local application preferences and a security-scoped bookmark.
4. Build artifacts inside the repository's ignored `build/` and `.build/` directories.

Autosave reads the current disk revision immediately before atomic replacement. A mismatch becomes a conflict instead of an overwrite.

Application termination uses the same synchronous save/conflict gate as document switching. Pending edits are flushed before quitting; an unresolved conflict or failed save cancels termination and brings the document window forward. This does not protect against force quit or system failure.

Preview updates cache the last source, document/workspace URLs, theme and reading appearance before parsing. Scroll synchronization and unrelated SwiftUI updates therefore skip Markdown parsing, highlighting and local image encoding. Changing an input renders again. Image-only external changes require reopening the preview; no background asset watcher is introduced.

Build and release entry points are documented in [RELEASING.md](RELEASING.md). Packages retain exact dependency license files and are ad-hoc signed, verified before replacing the prior build, then checked again after ZIP extraction.

## macOS compatibility

The package deployment target is macOS 15. APIs introduced after macOS 15 require availability checks and a macOS 15 implementation path.
