# Plainleaf MVP product specification

## Core flow

1. Open a folder through the macOS folder picker.
2. Browse its non-hidden directory structure and supported Markdown files.
3. Select a document and edit its Markdown source.
4. Let Plainleaf save changes atomically without hiding failures.
5. Move the same document among source, synchronized split, and carefully typeset reading modes.
6. Quit and reopen Plainleaf with the last authorized workspace and state restored.

## Workspace search

- `Shift-Command-F` focuses the always-visible library search field.
- Searches supported Markdown file paths and UTF-8 contents inside the authorized workspace.
- Matching is case-, width-, and diacritic-insensitive and ranks path matches before content-only matches.
- Results show the relative path, total text-match count, and up to three matching source lines per file.
- Selecting a line opens that document in source mode, selects the matching text, and transfers keyboard focus to the editor.
- The current open document is searched from its in-memory text, so unsaved edits do not disappear from results.
- Search work is debounced and cancellable. Results are capped at 80 notes and are never persisted as an index or workspace metadata.

## Supported workspace files

Plainleaf lists directories and files ending in `.md`, `.markdown`, or `.mdown`. It ignores hidden entries and does not follow symbolic links. Other files are not displayed or modified.

## Editing

- Plain Markdown source, not inline WYSIWYG
- Markdown syntax highlighting
- Native undo and redo
- Native find bar
- Bold, italic, inline-code, and link shortcuts
- Debounced autosave plus an explicit Save command
- New Markdown file through a save panel rooted in the active workspace

## Reading

- Semantic HTML/CSS rendered inside a JavaScript-disabled local `WKWebView`
- Headings, paragraphs, emphasis, strong text, strike-through, inline code
- Ordered and unordered lists, task lists, block quotes, thematic breaks
- GFM tables
- Footnote references and root-level definitions using `[^label]` / `[^label]:`, including four-space or tab-indented continuation lines and multiple paragraphs
- Footnotes are numbered by first reference, repeated references receive distinct return links, escaped references remain literal, and undefined references are never hidden
- Fenced code with local syntax highlighting
- Local images resolved relative to the current document
- Relative Markdown links open inside Plainleaf; web links open in the default browser
- Footnote references and return links use controlled same-document fragment navigation with keyboard focus transferred to the destination
- Reading appearance uses a bounded 15.5–22.5 text-size scale, Compact/Book/Open line spacing, and Narrow/Balanced/Wide page measures
- The appearance panel is available wherever the HTML surface is visible; `Command-Plus`, `Command-Minus`, and `Command-0` adjust or reset text size without editing Markdown
- A collapsible sidebar outline mirrors the document heading hierarchy, jumps to matching HTML anchors, and follows the current section while the HTML surface scrolls
- Raw HTML is shown as source text and is never executed
- Remote images, SVG, and local images outside the authorized workspace are represented by privacy placeholders and are never fetched automatically

## View modes

- Source mode keeps the full document width for focused Markdown editing.
- Split mode places the editable Markdown source and the same semantic HTML preview side by side with a draggable native divider.
- Source and preview exchange normalized scroll progress in both directions while split mode is active. This is proportional document-position synchronization, not a promise that unlike source and rendered layouts share exact line geometry.
- Entering split mode inherits the visible pane's current position. Leaving split mode preserves the corresponding source or preview position.
- Reading mode keeps the responsive HTML surface centered for distraction-reduced reading.
- Reading appearance is stored in local application preferences and applies to both Split and Read. It does not write CSS, fonts, or metadata into the workspace.
- The current mode is stored in local application preferences; `Shift-Command-R` cycles Source, Split, and Read.

## Standalone HTML export

- `File > Export HTML…` or `Shift-Command-E` exports the current in-memory Markdown, including edits that have not yet reached disk.
- The output is one UTF-8 `.html` file using the current Light or Dark theme and reading appearance. Verified local raster images are embedded as data URLs; no asset folder is created.
- The app-bundled reading font is not copied into exported HTML. A viewer with LXGW WenKai GB Lite installed can use it; otherwise the document falls back to the platform serif stack without a network request.
- The exported document retains semantic HTML, syntax highlighting, footnotes, print CSS, the restrictive CSP, no-referrer metadata, and a `script-src 'none'` / `connect-src 'none'` runtime boundary.
- Page fragments, relative links, HTTPS/HTTP links, and mail links remain clickable. Plainleaf-specific URLs are removed; executable, data, file, protocol-relative, absolute-path, control-character, and unsupported-scheme destinations render as visibly blocked text.
- Relative links remain relative to the exported file. Moving the file away from linked documents can therefore break those links; linked Markdown files are not silently copied or converted.
- The destination is chosen explicitly in a standard save panel and written atomically. Export never rewrites the source Markdown or creates workspace metadata.

## Visual language

- Light: cool fog canvas, near-white surfaces, graphite text, deep blue emphasis, and restrained orange warnings
- Dark: charcoal canvas and lifted graphite surfaces, softened light text, pale blue emphasis, and adjusted orange warnings
- UI: SF Pro Rounded with PingFang SC fallback; source and data labels: SF Mono; reading: bundled LXGW WenKai GB Lite with system serif fallbacks; code: SF Mono
- One collapsible library sidebar with an optional page index and a floating rounded document control shelf; single-pane modes use a centered surface while Split keeps a native draggable divider
- Search temporarily replaces the library tree with compact rounded result groups; clearing it restores the tree and reading outline
- Selected notes and the active outline heading share the same soft blue selection surface, reinforced by system icons and font weight rather than color alone
- Theme follows the system by default and can be fixed to Light or Dark

## Data and privacy

- No network requests initiated by Plainleaf
- The sandbox network-client entitlement exists only so macOS can launch WKWebView helper processes; it does not authorize remote loading in the generated preview
- No telemetry or crash uploads
- No application metadata written into user workspaces
- No search index written to disk; queries and results stay in application memory
- Security-scoped bookmarks are stored in local application preferences
- External file changes are reloaded only when safe; conflicting changes stop autosave
