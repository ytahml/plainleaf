# MVP acceptance checklist

## Automated

- Workspace enumeration filters extensions, hidden entries, and symlinks.
- Disk revision fingerprints detect external changes.
- Document sessions save atomically and refuse conflicts.
- Markdown parsing covers the supported GFM nodes and treats HTML as text.
- Footnote parsing covers first-reference numbering, repeated references, multiline definitions, inline formatting, escaped/undefined literal syntax, and fenced-code exclusion.
- HTML generation escapes raw HTML, applies a restrictive CSP, and never emits remote image sources.
- HTML footnotes use semantic document roles, unique reference identifiers, per-occurrence back links, and controlled local-fragment navigation in a real JavaScript-disabled `WKWebView`.
- Reading appearance clamps text sizes, round-trips through isolated application defaults, maps named leading and measure presets to controlled CSS variables, and never restores malformed values unchecked.
- Standalone HTML export writes one UTF-8 file, embeds allowed local images, preserves theme and reading variables, resets heading anchors per render, removes `plainleaf://`, retains safe link kinds, and visibly blocks executable or local-file schemes.
- Relative links and local raster images cannot escape the authorized workspace silently; SVG remains blocked.
- A real `WKWebView` loads the generated document, resolves the bundled LXGW WenKai GB Lite face, and produces a non-blank snapshot.
- The document outline preserves heading order and hierarchy, shares duplicate-safe anchors with HTML output, safely encodes its reveal command, moves a real `WKWebView` to the selected heading, and identifies the active heading at the page start, a revealed section, and the document bottom.
- Split-scroll metrics clamp and normalize offsets, preserve the visible pane's position on entry, publish origin-tagged updates, and reset per document.
- Workspace search covers path/content ranking, case/width/diacritic-insensitive matching, line snippets, result limits, current in-memory text, unreadable files, and safe source-range fallback.
- `swift test` and `swift build` pass with the macOS 15 deployment target.

## Manual on macOS 15.7

- First launch shows the Plainleaf welcome surface without writing sample files.
- A chosen folder reopens after quitting and relaunching.
- The sidebar shows nested Markdown files and excludes hidden, unsupported, and symlinked entries.
- Typing, undo/redo, find, formatting shortcuts, autosave, and explicit save work.
- An external edit reloads when the document is clean.
- Concurrent local and external edits produce a visible conflict and do not overwrite either version.
- HTML reading mode renders headings, mixed Chinese/English text, lists, tasks, tables, quotes, footnotes, local images, and fenced code.
- Footnote numbers remain visually subordinate and keyboard-focusable; selecting a reference moves to its endnote, each return link moves to the exact occurrence, and both Light and Dark remain readable.
- Reading appearance changes text size, line spacing, and page width live in Split and Read; keyboard shortcuts work, Source hides the irrelevant control, Reset restores the book defaults, and choices survive relaunch.
- Split mode shows editable Markdown and the responsive HTML preview together, exposes a draggable divider, synchronizes proportional scrolling in both directions, and preserves position while cycling Source, Split, and Read.
- The reading sidebar lists document headings, preserves their relative hierarchy, jumps to sections, follows direct or split-synchronized HTML scrolling with one accessible current-section selection, collapses through its header or `Option-Command-O`, and remembers that preference after relaunch.
- `Shift-Command-F` focuses workspace search without stealing focus at launch; body and path queries show accessible results, line results select and focus source text across documents, the empty state is actionable, and Escape restores the library.
- Remote images do not cause network loading and raw HTML does not execute.
- Light and Dark remain readable, mixed Chinese/English text uses the bundled reading face cleanly, and keyboard navigation has visible focus.
- The system print panel opens from split or reading mode and can save a PDF.
- `Shift-Command-E` opens a save panel with an `.html` name; the resulting single file loads offline with the current reading settings and documented system-font fallback, semantic content, local images, footnotes, and no remote resources or executable raw HTML.
- The locally packaged `Plainleaf.app` launches on macOS 15.7.

## Evidence boundary

Passing automated checks does not imply the manual checklist passed. Local packaging does not imply signing, notarization, Intel compatibility, public release, or App Store readiness.
