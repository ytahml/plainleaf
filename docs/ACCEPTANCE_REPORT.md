# MVP acceptance report

Date: 2026-08-30

Host: macOS 15.7.7, Apple silicon

Toolchain: Xcode 26.1.1, Swift 6.2.1, macOS SDK 26.1

## Verified automatically

- `swift test`: 11 tests passed with no failures.
- Flexoki Light and Dark text, secondary text, blue emphasis, and orange warning colors meet the 4.5:1 contrast floor against their document surfaces; primary text exceeds 7:1.
- Workspace enumeration excludes hidden, unsupported, and symlink entries.
- UTF-8 atomic writes, explicit saves, clean external reloads, and conflict refusal are covered by tests.
- GFM tables, tasks, strikethrough, inert raw HTML, and image-source parsing are covered by tests.
- `scripts/build-app.sh` produced `build/Plainleaf.app`.
- Strict deep signature verification passed.
- The packaged executable declares macOS 15.0 as its minimum OS and macOS SDK 26.1 as its SDK.
- The original packaged sandbox entitlements were limited to app sandboxing, user-selected read/write access, app-scoped bookmarks, and printing.

## Verified manually on macOS 15.7.7

- First launch displayed the welcome surface without creating sample files.
- The fixed acceptance workspace opened and restored after quitting and relaunching.
- Nested Markdown files appeared in the sidebar.
- Source editing, a formatting shortcut, and autosave updated an ordinary Markdown file; the fixture was restored afterward.
- A clean external edit appeared in the open document; the fixture was restored afterward.
- Reading mode rendered headings, mixed Chinese and English text, lists, tasks, tables, highlighted Swift code, and a local image.
- A remote image remained a blocked placeholder and raw HTML remained visible source.
- A relative Markdown link opened the destination inside Plainleaf and exposed an accessible button role.
- Flexoki Light and Dark both rendered correctly in the packaged app.
- Source mode was checked at the narrower writing measure and increased SF Mono spacing; reading mode was checked with Charter, mixed Chinese/English fallback, tables, quotes, inline code, and fenced code.
- The system print panel opened with a page preview and PDF control.
- The final locally packaged app launched successfully.

## Not yet manually accepted

- The concurrent local/external edit conflict banner was not timing-raced through the UI. Its no-overwrite behavior is covered by an automated session test.
- Undo/redo, find, explicit save, and every keyboard-focus path were not each exercised in the packaged app during this pass.

## HTML preview migration evidence

The following evidence is newer than the original manual pass above and applies to the HTML/WKWebView preview migration:

- Implementation: Markdown is parsed into Plainleaf-owned nodes, converted to semantic HTML with Plainleaf-owned CSS, and loaded in a JavaScript-disabled `WKWebView` with a restrictive CSP.
- Automated checks: 18 tests passed. They cover escaping raw HTML, blocking remote images and SVG, preventing local-image symlink escapes, link encoding, heading anchors, both themes, and real WebKit DOM loading plus non-blank snapshots.
- Visual checks: WebKit snapshots for Flexoki Light and Dark were inspected with mixed Chinese/English text, tasks, a quote, a table, inline code, and highlighted fenced code.
- Packaging: `scripts/build-app.sh` succeeded; strict deep signature verification passed; the app declares sandbox, user-selected file, app-scoped bookmark, network-client, and print entitlements; the minimum OS remains macOS 15.0. The network-client capability is required for macOS to launch WebKit helper processes, while CSP and generated-content tests continue to prohibit remote preview resources and connections.
- Packaged-app interaction (refreshed 2026-08-31): the fixed workspace produced a real WebContent accessibility tree; the relative writing-guide link opened the destination inside Plainleaf; switching from Flexoki Light to Dark preserved the exact scroll-bar position (`0.7497436`); both File > Print and `Command-P` opened the system print sheet with two page previews, printer settings, and the PDF menu. The final sheet was cancelled without creating a print job.
- Manual boundary: saving an actual PDF and the complete packaged-app keyboard checklist have not yet been refreshed. The pre-migration manual results above do not substitute for these checks.

## Document outline iteration

Evidence refreshed on 2026-08-31:

- Implementation: reading mode now presents a collapsible "On this page" index in the existing library sidebar. Relative indentation and leaf-vein markers encode heading hierarchy without narrowing the document surface.
- Anchor contract: the outline and HTML renderer share one duplicate-safe identifier generator, including Unicode headings and empty-title fallback behavior.
- Automated checks: `swift test` passed 23 tests with no failures. New coverage verifies hierarchy, nested headings, duplicate anchors, JSON-safe reveal commands, HTML/outline anchor parity, and a real WebKit scroll to the selected heading.
- Packaged-app interaction: clicking the second heading moved the reading scrollbar from `0` to `0.2841026`; clicking the first moved it back to `0.0625641`. The outline collapsed from its accessible header, expanded with `Option-Command-O`, retained its collapsed state across quit/relaunch, and remained absent in source mode.
- Visual check: the packaged Paper-theme app was inspected at the default window size. The page index remained visually subordinate to the file library and reused the existing leaf-vein motif; no overlay covered or narrowed the reading paper.
- Boundary: this iteration adds no workspace metadata, remote access, Markdown writes, or synchronized active-heading tracking while the user scrolls manually.

## Workspace search iteration

Evidence refreshed on 2026-08-31:

- Implementation: the library sidebar now contains a local path/content search field. Queries are debounced and cancellable; the current open document contributes its in-memory text, and results are never persisted as an index.
- Result contract: case-, width-, and diacritic-insensitive matching ranks path matches first, counts every text occurrence, keeps up to three line snippets per file, caps display at 80 notes, and reports unreadable UTF-8 files.
- Source navigation: selecting a line opens the matching Markdown file in source mode, re-finds the query defensively on that line, selects it, and moves keyboard focus from search to the editor. No document text is changed by reveal.
- Automated checks: `swift test` passed 28 tests with no failures. New coverage verifies Unicode matching, ranking, snippet and result limits, unsaved-text overrides, unreadable-file reporting, flattened non-symlink file input, and source-range fallback.
- Packaged-app interaction: `Shift-Command-F` focused search without stealing focus at launch. `Markdown` returned Welcome and Large with line snippets; `Writing.md` returned both a path-only Guides/Writing result and Welcome's link source; `technical writers` opened Large line 5 and exposed `technical writers` as the selected editor text. A deliberately absent query showed the actionable empty state, and Escape restored the library and reading outline.
- Visual check: the result list was inspected in the packaged Paper-theme app. Relative paths, monospaced line labels, restrained blue highlights, and leaf-vein file markers remained readable in the existing 285-point sidebar without covering the document.
- Boundary: the fixed three-note workspace was exercised, but large-workspace latency and memory use have not yet been manually stress-tested. Search remains limited to supported UTF-8 Markdown files already admitted by `WorkspaceStore`.

## Split preview iteration

Evidence refreshed on 2026-08-31:

- Implementation: Source, Split, and Read are explicit persisted modes. Split uses a native draggable divider, a compact AppKit source editor, the responsive HTML/WKWebView surface, and a document-scoped controller for bidirectional normalized scroll progress.
- Synchronization contract: AppKit clip-view changes drive source-to-preview movement; a 100 ms native timer samples WebKit scroll metrics for preview-to-source movement. Updates carry their origin and suppress programmatic echo loops. The loaded page still has content JavaScript disabled, no embedded scripts, and the existing restrictive CSP.
- Automated checks: `swift test` passed 34 tests with no failures. Five focused tests cover local position recording, clamping and publishing, split-entry inheritance, per-document reset, and offset normalization; mode persistence includes the Split raw value.
- Packaged-app interaction: the formal local bundle exposed both the editable source and real WebContent accessibility trees. Moving source to `0.6947891` moved preview to `0.7188184`; moving preview to `0.1805252` moved source to `0.1797305`. The small difference reflects unlike source/rendered document geometry and is within the proportional synchronization contract.
- Divider and mode interaction: the source/preview divider changed from `427.5` to `520` and back. `Shift-Command-R` cycled Split to Read, Read to Source, and Source to Split while keeping the document near the same normalized position; the outline remained available whenever the HTML surface was visible.
- Printing and packaging: `Command-P` from Split opened the macOS print sheet with two page previews and PDF controls; the sheet was cancelled without a job. `scripts/build-app.sh` then rebuilt the ad-hoc signed local app, and `git diff --check` passed.
- Visual check: the Paper-theme split layout was inspected at the default window size and with unequal pane widths. Quiet monospaced pane labels, the shared synchronization marker, native seam, compact source insets, and responsive HTML measure kept the editor's-desk hierarchy legible without overlaying content.
- Boundary: synchronization is proportional, not semantic source-line-to-DOM mapping. Very large-document scrolling performance and every possible resize width have not yet been manually stress-tested. No standalone HTML/PDF file was exported in this pass.

## Active-section outline tracking iteration

Evidence refreshed on 2026-08-31:

- Implementation: the existing WebKit polling bridge now returns normalized scroll progress and the active heading anchor in one evaluation. The active heading is the last titled section above a bounded viewport threshold, with explicit first-section and document-bottom behavior.
- State boundary: `AppModel` accepts an anchor only for the currently open document and does not persist it. Changing documents clears the state. The generated HTML still contains no script, and WebKit content JavaScript remains disabled.
- Sidebar behavior: the current item uses the existing leaf-vein marker at full accent strength, a restrained tinted background, stronger text, the selected accessibility trait, and the value “Current section.” `ScrollViewReader` keeps an active item visible without adding decorative animation.
- Automated checks: `swift test` passed 35 tests with no failures. A focused value-bridge test covers progress clamping, anchor parsing, null anchors, and invalid results. A real JavaScript-disabled WebKit test identifies the first heading at page start, the selected target after `scrollIntoView`, and the final heading at document bottom.
- Packaged-app interaction: the formal app initially exposed “Welcome to Plainleaf” as the selected current section. Moving the reading scrollbar to `0.3497436` selected “MVP checklist.” In Split, moving the source scrollbar back to `0.0001289` synchronized preview to `0` and selected “Welcome to Plainleaf” again.
- Visual check: the Paper-theme outline was inspected while “MVP checklist” was active. The tinted bookmark row and strengthened leaf vein were unambiguous but remained subordinate to the HTML reading surface.
- Packaging: `scripts/build-app.sh`, strict deep code-signature verification, and `git diff --check` passed after this iteration.
- Boundary: the fixed two-heading acceptance note proves state changes but does not manually stress automatic centering in an outline longer than its 218-point viewport. Active-section state is intentionally ephemeral and does not alter Markdown or workspace metadata.

## Footnote rendering iteration

Evidence refreshed on 2026-08-31:

- Implementation: Plainleaf adds a controlled footnote extension ahead of `swift-markdown`. It extracts root-level definitions outside fenced code, preserves indented continuation paragraphs, protects escaped references, numbers notes by first reference, keeps undefined syntax literal, and parses footnote bodies back into the existing render-node model.
- HTML contract: references render as compact `doc-noteref` superscripts; the Notes section uses `doc-endnotes` / `doc-endnote`, stable identifiers, and a return link for every occurrence. Paper and Ink CSS reuse the reader, utility, mono, accent, border, and selection tokens; print keeps each endnote together when possible.
- Navigation correction: the first packaged-app pass exposed WebKit fragment values as `about:blank%23…`; the previous delegate gave those links focus but cancelled their movement. The final implementation explicitly decodes safe same-document `about` fragments, cancels page navigation, and uses a JSON-encoded native bridge to update the fragment, center, and focus the existing target.
- Automated checks: `swift test` passed 41 tests with no failures. New tests cover first-reference order, repeated occurrences, multiline formatting, undefined and fenced syntax, escaped references, semantic HTML/back links, WebKit reference-to-note-to-reference travel, encoded fragment recognition, and anchor escaping.
- Packaged-app interaction: the fixed workspace now contains four notes, including `Footnotes.md`. The final formal bundle exposed three accessible footnote-reference links, two endnotes, two back links for the repeated source, one bilingual endnote, inline code, emphasis, and a local Markdown link. Selecting Footnote 2 moved the scrollbar from `0` to `1` and focused the Chinese/English endnote; its return link restored the scrollbar to `0` and the exact reference fragment.
- Visual check: Paper and Ink were inspected at the default window size. Small blue reference numbers stayed subordinate to New York/Songti prose; the thin rule, monospaced Notes label, smaller endnote measure, accent list markers, and restrained return marks read as a book-style apparatus rather than a separate card surface.
- Packaging: the local ad-hoc bundle rebuilt, strict deep code-signature verification passed, and the original Flexoki Light preference plus Welcome document were restored before the app exited.
- Boundary: definitions are recognized at the document root with up to three leading spaces; continuation content requires four spaces or a tab. Definitions nested inside block quotes or list items are not supported in this iteration. Math and Mermaid remain deferred. No Markdown file is rewritten by preview parsing.

## Reading appearance iteration

Evidence refreshed on 2026-08-31:

- Implementation: a bounded `ReadingAppearance` model now owns screen text size (15.5–22.5 in half-point-safe values), Compact/Book/Open leading, and Narrow/Balanced/Wide page measures. The values persist only in application defaults; no CSS, font, index, or metadata is written into the workspace.
- HTML contract: `HTMLDocumentRenderer` serializes the three values into Plainleaf-owned `--body-size`, `--body-leading`, and `--paper-width` variables. The JavaScript-disabled WebKit boundary, restrictive CSP, semantic document structure, fixed local font stack, and print stylesheet are unchanged.
- Interface and commands: an accessible typesetter-style panel with a live New York/Songti specimen appears in Split and Read but not Source. `Command-Plus`, `Command-Minus`, and `Command-0` increase, decrease, or reset reading text size through the Reading menu.
- Automated checks: `swift test` passed 44 tests with no failures. New coverage verifies clamping and half-point normalization, named preset values, an isolated `UserDefaults` round trip, CSS-variable injection, and removal of the former mobile font-size override that would have ignored the selected value.
- Packaged-app interaction: the formal bundle changed text size from 17.5 to 18.5 from both the panel and `Command-Plus`; `Command-Minus` and `Command-0` restored it. Open leading and Wide measure exposed selected accessible states, survived quit/relaunch, remained available in Split, and disappeared in Source. Reset restored 17.5 / Book / Balanced and disabled itself at that state.
- Visual check: the default Paper page, enlarged text, Wide/Open composition, and the corresponding Ink surface were inspected at the default window size. The live control kept the existing quiet editor's-desk hierarchy; mixed Chinese/English text, task rows, quotation treatment, and the page edge remained legible.
- Packaging: `scripts/build-app.sh` rebuilt the local ad-hoc bundle and strict deep code-signature verification passed. Flexoki Light, Welcome, Read mode, and standard appearance were restored after acceptance.
- Boundary: these are screen-reading controls, not arbitrary custom CSS, bundled-font selection, or standalone-export settings. The print stylesheet retains its fixed paper-oriented typography. No Markdown content was edited during this iteration.

## Standalone HTML export iteration

Evidence refreshed on 2026-08-31:

- Implementation: `HTMLDocumentRenderer` now accepts preview or standalone purpose behind the same rendering interface. Standalone output adds a document title, generator and no-referrer metadata, uses the current theme and reading appearance, embeds verified raster images, and retains the existing semantic HTML, syntax highlighting, footnotes, print rules, CSP, and inert raw-HTML behavior.
- Link and state contract: standalone mode removes `plainleaf://`; keeps fragments, relative paths, HTTP/HTTPS, and mail links; and turns executable, data, file, protocol-relative, absolute-path, control-character, or unknown schemes into visibly blocked text. Every render resets its heading generator, so reuse cannot drift the first anchor to a duplicate suffix.
- File module: `StandaloneHTMLExport` owns suggested `.html` naming, UTF-8 bytes, and one atomic `write(to:)` operation. `AppModel` supplies the current in-memory Markdown and presents a standard save panel; exporting does not save, rewrite, or add metadata to the Markdown workspace.
- Automated checks: `swift test` passed 46 tests with no failures. New coverage verifies portable and blocked links, no native scheme leakage, embedded image data, CSP continuity, UTF-8 single-file writing, Ink plus custom reading values, Chinese naming, and stable anchors across repeated renderer calls.
- Packaged-app interaction: File > Export HTML exposed the native command and a panel suggesting `Welcome.html` with an explicit one-file/offline explanation. It saved the preflighted unique path `/tmp/plainleaf-standalone-export-20260831-0118.html` and presented an accessible success alert. `Shift-Command-E` independently reopened the same panel; that second pass was cancelled without creating another file.
- Disk evidence: the export is one 34,557-byte UTF-8 HTML file. Read-only inspection found `<title>Welcome</title>`, the standalone purpose marker, and an embedded PNG data URL; it found no `plainleaf://`, remote `src`, executable `href`, or script element. No adjacent asset directory or second matching export artifact was created.
- Visual and accessibility check: Finder Quick Look loaded the exported file from disk with headings, bilingual prose, task states, quotation, table, highlighted Swift, embedded Plainleaf image, relative writing-guide link, remote-image placeholder, and inert raw script source. The refreshed screenshot matched the Paper reading composition. Safari's file-URL permission flow returned to its start page, so it is not counted as render evidence; the temporary Safari tab and Finder test window were closed afterward.
- Packaging: the production bundle rebuilt, strict deep signature verification and `git diff --check` passed before manual export. The exported `/tmp` file is retained as recoverable evidence rather than deleted.
- Boundary: relative destinations remain relative to the exported file and can break if it is moved away from linked documents; Plainleaf does not silently copy or convert linked Markdown. Dedicated PDF export remains deferred. This feature is local file export, not remote publication.

## Review repair iteration

Evidence refreshed on 2026-08-31:

- Implementation: synchronized scroll reports now refresh both pane caches; footnotes use a colon-delimited internal ID namespace that heading anchors cannot produce; and the footnote preprocessor rejects definition candidates whose source location belongs to a parsed list item.
- Regression coverage: new tests exercise both synchronized scroll directions plus independent single-pane caches, heading/footnote/repeated-label ID collisions, complete fragment-target resolution, real JavaScript-disabled WebKit note/back-link navigation, nested-list definition rejection, and one-to-three-space root definitions after lists.
- Automated checks: `swift test` passed 51 tests with no failures. `git diff --check` also passed.
- Packaging: `scripts/build-app.sh` completed a production build. The local app passed strict deep code-signature verification, retained its sandbox/bookmark/user-file/network-client/print entitlements, and declared macOS 15.0 as the minimum system version.
- Packaged-app interaction: on macOS 15.7.7 arm64, source scrolling moved Source and Preview to approximately `0.9418` / `0.9416`; switching to Read preserved `0.9418`. Preview scrolling then moved Preview and Source together to approximately `0.8575`; switching to Source remained in the same lower-document region at `0.8391` rather than restoring a stale position or returning to the top. The difference after changing layout is within the proportional-position contract.
- Footnote interaction: the packaged fixture exposed `plainleaf:fn:…` and `plainleaf:fnref:…:<occurrence>` targets. Footnote 2 moved the reader scrollbar from `0` to `1`, and its exact return link restored `0`.
- State and boundary: UI acceptance used a generated long Markdown file under `/private/tmp`; the tracked acceptance fixture was not edited. The app was restored to AcceptanceWorkspace, Welcome, Read mode, Flexoki Light, standard appearance, and a clear search field. No commit, push, release, notarization, or publication was performed.

## Publication boundary

The source repository is public on GitHub. The app itself remains a local Apple-silicon development build with an ad-hoc signature; it has not been Developer ID signed, notarized, tested on Intel, released, or submitted to the App Store.
