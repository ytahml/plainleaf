# Plainleaf · 素页

Plain files. Beautifully read.

Plainleaf is a local-first Markdown editor and reader for macOS. It opens a folder you choose, edits ordinary Markdown files in place, and turns them into a calm reading surface without introducing a private document format.

## MVP

- Native SwiftUI application with focused AppKit bridges
- Sandboxed folder access with a restorable security-scoped bookmark
- Markdown-only workspace tree
- Source editing with syntax highlighting, undo, find, and formatting shortcuts
- Debounced atomic autosave with external-change conflict protection
- GFM reading mode with tables, task lists, fenced code, and local images
- Paper and Ink themes using macOS system fonts
- System printing and PDF through the macOS print panel
- No telemetry, accounts, remote image loading, or hidden workspace metadata

## Requirements

- macOS 15 or newer
- Xcode 26.1 or newer for the current development setup
- Swift 6.2 or newer

## Build and test

```sh
swift test
swift build
./scripts/build-app.sh
open build/Plainleaf.app
```

The first public release is intentionally out of scope. The current bundle identifier is provisional and the generated app is ad-hoc signed for local use.

The fixed checklist and current evidence are recorded in [`docs/ACCEPTANCE.md`](docs/ACCEPTANCE.md) and [`docs/ACCEPTANCE_REPORT.md`](docs/ACCEPTANCE_REPORT.md).

## License

Plainleaf is released under the MIT License. Dependency notices are documented in `docs/THIRD_PARTY_NOTICES.md`.
