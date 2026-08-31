# Plainleaf project memory

## Product contract

- Name: Plainleaf; Chinese presentation name: 素页.
- Audience: technical writers who want a native, lightweight Mac Markdown tool.
- Promise order: native and fast, then beautiful typography, then immersive reading.
- Files stay as ordinary Markdown in a user-selected folder. Plainleaf writes no hidden workspace metadata.
- MVP is local-only and English-first. No analytics, update checks, accounts, cloud sync, collaboration, AI, plugins, or publishing.

## MVP boundary

- Include: one workspace in one window, Markdown file tree, new Markdown file, source editing, autosave, external conflict protection, reading-mode toggle, GFM, fenced-code highlighting, local images, Paper/Ink themes, state restoration, system printing, accessibility baseline, tests, and a locally launchable app bundle.
- Exclude: tabs, full-text search, outline, split preview, math, Mermaid, footnotes, managed image copying, custom CSS/fonts, dedicated PDF/HTML export, delete/move/bulk rename, and remote image loading.

## Technical decisions

- Swift 6.2, SwiftUI with focused AppKit bridges, Swift Package Manager.
- Deployment target macOS 15.0; manual acceptance must run on the maintainer's macOS 15.7 system.
- Parse Markdown with swift-markdown 0.8.x, convert the controlled node set to semantic HTML, and render it in a JavaScript-disabled WKWebView with a restrictive CSP.
- Highlight fenced code with HighlighterSwift 3.1.x.
- Do not execute raw HTML. Do not fetch remote resources automatically.
- Embed only verified local raster images inside the authorized workspace; block remote images, SVG, unavailable paths, and symlink escapes with visible placeholders.
- The sandboxed app requires `com.apple.security.network.client` for macOS to launch WKWebView WebContent/Networking helper processes. This is not a product network feature: generated HTML has no remote resources, JavaScript is disabled, CSP blocks connections, and WebView navigation is intercepted.
- Save UTF-8 using atomic replacement only after confirming the disk fingerprint still matches the loaded revision.
- The interface uses a focused editor's-desk layout with centered document surfaces and a shared leaf-vein marker for file selection and level-one reading headings. Its light/dark colors adapt the MIT-licensed Flexoki palette for prose and code. SF Pro with PingFang SC fallback and SF Mono remain native UI/editor faces; reading uses the macOS system serif (New York) with Songti SC and system fallbacks for coherent mixed-language screen reading on macOS 15.
- The source repository is public at `https://github.com/ytahml/plainleaf` as of 2026-08-30. This does not authorize a binary release, notarization, App Store submission, or deployment.

## Verification boundary

- Report implementation, automated checks, local app packaging, and manual acceptance separately.
- Do not call the MVP complete until the fixed acceptance workspace has been exercised on macOS 15.7.

## Post-MVP local iterations

- Document outline is now delivered locally. It appears whenever an HTML surface is visible in split or reading mode, shares the HTML renderer's duplicate-safe anchors, preserves relative heading hierarchy, follows the active HTML section, collapses from the sidebar or `Option-Command-O`, and stores only its expanded/collapsed preference in application defaults. The current heading itself remains ephemeral.
- Full-workspace search is now delivered locally. It searches only the already-filtered Markdown file list, overlays the current document's in-memory text, ranks path matches before content matches, exposes up to three source-line snippets per file, and keeps queries/results in memory rather than writing an index.
- Search uses `Shift-Command-F`, caps displayed results at 80 notes, and transfers selection/focus to the source editor for line results. The three-note acceptance workspace is verified; large-workspace performance remains unmeasured manually.
- Split preview is now delivered locally. Source, Split, and Read are persisted modes; `Shift-Command-R` cycles them. Split uses a native draggable divider and exchanges normalized scroll progress in both directions through an origin-tagged in-memory controller. Synchronization is proportional, not semantic Markdown-line-to-DOM mapping.
- Footnotes are now delivered locally as a Plainleaf-controlled extension ahead of `swift-markdown`. Root-level definitions support indented multiline bodies; references are numbered by first use; repeated references have distinct back links; escaped/undefined/code syntax stays literal. The HTML uses semantic roles and controlled same-document navigation without enabling content JavaScript. Nested block/list definitions remain unsupported.
- Reading appearance is now delivered locally. A bounded model persists 15.5–22.5 text size, Compact/Book/Open leading, and Narrow/Balanced/Wide page measure in application defaults. Split and Read expose a native typesetter panel plus `Command-Plus`, `Command-Minus`, and `Command-0`; Source hides the control. The values become Plainleaf-owned CSS variables and never workspace CSS or metadata.
- Standalone HTML export is now delivered locally. `Shift-Command-E` writes the current in-memory Markdown as one atomic UTF-8 file with the current theme/reading appearance and embedded authorized raster images. It shares semantic HTML/CSS/CSP with preview, removes the native `plainleaf://` bridge, preserves page/relative/HTTP/HTTPS/mail links, and visibly blocks executable, data, file, absolute-path, protocol-relative, control-character, and unknown schemes. Relative link targets are not copied.

## Current verification status

- On 2026-08-30, the HTML preview migration reached 18 automated tests, including real WKWebView DOM/snapshot checks for both themes. The formal sandboxed bundle passed strict deep signature verification, declares the sandbox/bookmark/file/network-client/print entitlements required by its feature set, and keeps macOS 15.0 as its minimum OS.
- The packaged executable declares macOS 15.0 as its minimum OS; manual acceptance was performed on macOS 15.7.7.
- Before the HTML migration, core launch, workspace restoration, source editing/autosave, clean external reload, native reading, local/remote image boundaries, relative links, both Flexoki themes, and printing were exercised manually. That reading and printing evidence does not prove the post-migration WKWebView interactions.
- The conflict banner timing race and the full keyboard matrix remain outside manual evidence; conflict refusal is covered by an automated test.
- The source is published on GitHub; the Apple-silicon app build remains local, ad-hoc signed, and unreleased.
- On 2026-08-31, the New York and Songti SC HTML typography had fresh WebKit snapshot passes for both Paper and Ink. In the formal sandboxed package, real WebContent loaded, the relative Markdown link opened inside Plainleaf, the exact scroll position survived a Light-to-Dark theme change, and both File > Print and `Command-P` opened the system print sheet with two page previews plus PDF controls. Saving an actual PDF and the complete keyboard checklist remain unrefreshed.
- On 2026-08-31, the document-outline iteration raised the suite to 23 passing tests. The formal package showed accessible hierarchical heading buttons; two-way outline clicks moved the WebView, the header and `Option-Command-O` controlled collapse state, that preference survived relaunch, and the outline remained hidden in source mode. Active-heading tracking during manual scrolling remains deferred.
- On 2026-08-31, workspace search raised the suite to 28 passing tests. In the formal package, launch did not steal search focus; `Shift-Command-F`, content and path matches, cross-document line selection, source-editor focus, the empty state, and Escape-to-library were exercised. No fixture text was modified during this pass.
- On 2026-08-31, split preview raised the suite to 34 passing tests. In the formal package, both directions synchronized to closely matching normalized positions, the divider resized, `Shift-Command-R` cycled all three modes, the outline remained visible in Split/Read, and `Command-P` opened a two-page system print preview. The local ad-hoc bundle rebuilt successfully; large-document performance and perfect semantic line correspondence remain outside the evidence.
- On 2026-08-31, active-section outline tracking raised the suite to 35 passing tests. The JavaScript-disabled WebKit test covers first, revealed, and final heading detection. In the formal package, direct reading scroll selected “MVP checklist,” then split-mode source scrolling synchronized preview to the top and selected “Welcome to Plainleaf.” Long-outline auto-centering remains untested manually.
- On 2026-08-31, footnotes raised the suite to 41 passing tests. The formal package rendered repeated and bilingual notes in Paper and Ink; Footnote 2 moved from scrollbar `0` to `1`, and its return link restored `0`. An initial encoded-fragment navigation defect was fixed through an explicit local-anchor bridge. The four-note fixture, Flexoki Light preference, Welcome selection, and closed-app state were restored after acceptance.
- On 2026-08-31, reading appearance raised the suite to 44 passing tests. The formal package verified panel and shortcut size changes, all leading/measure selections, quit/relaunch persistence, Split availability, Source absence, Reset, and Paper/Ink visuals. The standard 17.5 / Book / Balanced state, Flexoki Light, Welcome, and Read mode were restored; the final package passed strict deep signature verification.
- On 2026-08-31, standalone HTML export raised the suite to 46 passing tests. The formal package exposed File > Export HTML and saved `/tmp/plainleaf-standalone-export-20260831-0118.html` through the native panel. The 34,557-byte single UTF-8 file contained its title, standalone marker, embedded PNG, no `plainleaf://`, remote image source, executable link, or script element. Finder Quick Look loaded the full accessible document and visibly matched Paper typography. Safari's file-URL permission flow returned to its start page and is not counted as render evidence; its temporary tab and the Finder test window were closed.
- On 2026-08-31, the post-review repair raised the suite to 51 passing tests. Synchronized reports now update both pane caches; packaged Source→Preview and Preview→Source scrolling survived exits from Split without stale restoration. Footnotes use collision-proof `plainleaf:fn:` / `plainleaf:fnref:` DOM namespaces and passed real WebKit navigation; `ListItem` source ranges prevent nested list syntax from being extracted as a root definition while preserving one-to-three-space root definitions. The production bundle passed strict deep signing and macOS 15.0 checks; AcceptanceWorkspace, Welcome, Read, Flexoki Light, and standard appearance were restored.
