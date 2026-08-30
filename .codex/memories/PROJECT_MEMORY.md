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
- Parse Markdown with swift-markdown 0.8.x and render a controlled node set inside Plainleaf.
- Highlight fenced code with HighlighterSwift 3.1.x.
- Do not execute raw HTML. Do not fetch remote resources automatically.
- Save UTF-8 using atomic replacement only after confirming the disk fingerprint still matches the loaded revision.
- The source repository is public at `https://github.com/ytahml/plainleaf` as of 2026-08-30. This does not authorize a binary release, notarization, App Store submission, or deployment.

## Verification boundary

- Report implementation, automated checks, local app packaging, and manual acceptance separately.
- Do not call the MVP complete until the fixed acceptance workspace has been exercised on macOS 15.7.

## Current verification status

- On 2026-08-30, 9 automated tests passed and the final app bundle passed strict deep signature verification.
- The packaged executable declares macOS 15.0 as its minimum OS; manual acceptance was performed on macOS 15.7.7.
- Core launch, workspace restoration, source editing/autosave, clean external reload, reading, local/remote image boundaries, relative links, both themes, and printing were exercised manually.
- The conflict banner timing race and the full keyboard matrix remain outside manual evidence; conflict refusal is covered by an automated test.
- The source is published on GitHub; the Apple-silicon app build remains local, ad-hoc signed, and unreleased.
