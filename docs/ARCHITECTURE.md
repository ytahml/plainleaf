# Architecture

## Layers

- `AppModel`: window-level orchestration, workspace lifecycle, selection, mode, theme, and commands.
- `WorkspaceStore`: sandbox authorization and read-only tree enumeration.
- `DocumentSession`: loaded text, autosave scheduling, disk revision fingerprints, and conflict state.
- `SourceEditor`: AppKit `NSTextView` bridge with native editing behavior and lightweight Markdown source highlighting.
- `MarkdownRenderer`: `swift-markdown` AST conversion into Plainleaf-owned render nodes.
- `ReaderView`: safe SwiftUI rendering for the supported node set; it never embeds arbitrary HTML or remote web content.

`HighlighterSwift` 3.1.0 is vendored with its upstream license. Plainleaf changes only its resource lookup order so a packaged app loads the library bundle from `Contents/Resources`; development builds still fall back to SwiftPM's `Bundle.module`.

## Write boundary

Plainleaf writes only:

1. A Markdown file explicitly selected or created by the user.
2. Local application preferences and a security-scoped bookmark.
3. Build artifacts inside the repository's ignored `build/` and `.build/` directories.

Autosave reads the current disk revision immediately before atomic replacement. A mismatch becomes a conflict instead of an overwrite.

## macOS compatibility

The package deployment target is macOS 15. APIs introduced after macOS 15 require availability checks and a macOS 15 implementation path.
