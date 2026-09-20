# Plainleaf · 素页

Plain files. Beautifully read.

Plainleaf is a local-first Markdown editor and reader for macOS. It opens a folder you choose, edits ordinary Markdown files in place, and turns them into a calm reading surface without introducing a private document format.

## MVP

- Native SwiftUI application with focused AppKit bridges
- Sandboxed folder access with a restorable security-scoped bookmark
- Markdown-only workspace tree
- Source editing with syntax highlighting, undo, find, and formatting shortcuts
- Debounced atomic autosave with external-change conflict protection
- HTML/CSS reading mode with GFM tables, task lists, fenced code, footnotes, and local images
- Local reading controls for text size, line spacing, and page width
- Single-file HTML export with embedded local images and no runtime network dependency
- Draggable split view with synchronized Markdown source and HTML preview scrolling
- Collapsible document outline with heading hierarchy, in-page navigation, and active-section tracking
- In-memory workspace search across Markdown paths and content, with line-level source navigation
- Native Light and Dark themes with bundled LXGW WenKai GB Lite reading typography
- System printing and PDF through the macOS print panel
- JavaScript-disabled preview with no telemetry, accounts, remote image loading, or hidden workspace metadata

## Requirements

- macOS 15 or newer
- Xcode 26.1 or newer for the current development setup
- Swift 6.2 or newer

## Build and test

```sh
swift test --force-resolved-versions
swift build
./scripts/build-app.sh
open build/Plainleaf.app
```

The app is ad-hoc signed (no Developer ID or notarization). `./scripts/package-release.sh` produces a verified ZIP, SHA-256 checksums, licenses, and build provenance. CI tests and packages Apple silicon and Intel builds; version tags create a draft release for manual publication. See [`docs/RELEASING.md`](docs/RELEASING.md) for the complete process and installation limitations.

The fixed checklist and current evidence are recorded in [`docs/ACCEPTANCE.md`](docs/ACCEPTANCE.md) and [`docs/ACCEPTANCE_REPORT.md`](docs/ACCEPTANCE_REPORT.md).

## License

Plainleaf is released under the MIT License. Dependency notices are documented in `docs/THIRD_PARTY_NOTICES.md`.
