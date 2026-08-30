# MVP acceptance report

Date: 2026-08-30  
Host: macOS 15.7.7, Apple silicon  
Toolchain: Xcode 26.1.1, Swift 6.2.1, macOS SDK 26.1

## Verified automatically

- `swift test`: 9 tests passed with no failures.
- Workspace enumeration excludes hidden, unsupported, and symlink entries.
- UTF-8 atomic writes, explicit saves, clean external reloads, and conflict refusal are covered by tests.
- GFM tables, tasks, strikethrough, inert raw HTML, and image-source parsing are covered by tests.
- `scripts/build-app.sh` produced `build/Plainleaf.app`.
- Strict deep signature verification passed.
- The packaged executable declares macOS 15.0 as its minimum OS and macOS SDK 26.1 as its SDK.
- The packaged sandbox entitlements are limited to app sandboxing, user-selected read/write access, app-scoped bookmarks, and printing.

## Verified manually on macOS 15.7.7

- First launch displayed the welcome surface without creating sample files.
- The fixed acceptance workspace opened and restored after quitting and relaunching.
- Nested Markdown files appeared in the sidebar.
- Source editing, a formatting shortcut, and autosave updated an ordinary Markdown file; the fixture was restored afterward.
- A clean external edit appeared in the open document; the fixture was restored afterward.
- Reading mode rendered headings, mixed Chinese and English text, lists, tasks, tables, highlighted Swift code, and a local image.
- A remote image remained a blocked placeholder and raw HTML remained visible source.
- A relative Markdown link opened the destination inside Plainleaf and exposed an accessible button role.
- Paper and Ink themes both rendered correctly.
- The system print panel opened with a page preview and PDF control.
- The final locally packaged app launched successfully.

## Not yet manually accepted

- The concurrent local/external edit conflict banner was not timing-raced through the UI. Its no-overwrite behavior is covered by an automated session test.
- Undo/redo, find, explicit save, and every keyboard-focus path were not each exercised in the packaged app during this pass.

## Publication boundary

The source repository is public on GitHub. The app itself remains a local Apple-silicon development build with an ad-hoc signature; it has not been Developer ID signed, notarized, tested on Intel, released, or submitted to the App Store.
