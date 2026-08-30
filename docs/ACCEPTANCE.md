# MVP acceptance checklist

## Automated

- Workspace enumeration filters extensions, hidden entries, and symlinks.
- Disk revision fingerprints detect external changes.
- Document sessions save atomically and refuse conflicts.
- Markdown parsing covers the supported GFM nodes and treats HTML as text.
- Relative links and local images cannot escape the authorized workspace silently.
- `swift test` and `swift build` pass with the macOS 15 deployment target.

## Manual on macOS 15.7

- First launch shows the Plainleaf welcome surface without writing sample files.
- A chosen folder reopens after quitting and relaunching.
- The sidebar shows nested Markdown files and excludes hidden, unsupported, and symlinked entries.
- Typing, undo/redo, find, formatting shortcuts, autosave, and explicit save work.
- An external edit reloads when the document is clean.
- Concurrent local and external edits produce a visible conflict and do not overwrite either version.
- Reading mode renders headings, mixed Chinese/English text, lists, tasks, tables, quotes, local images, and fenced code.
- Remote images do not cause network loading and raw HTML does not execute.
- Flexoki Light and Dark remain readable, mixed Chinese/English text falls back cleanly, and keyboard navigation has visible focus.
- The system print panel opens from reading mode and can save a PDF.
- The locally packaged `Plainleaf.app` launches on macOS 15.7.

## Evidence boundary

Passing automated checks does not imply the manual checklist passed. Local packaging does not imply signing, notarization, Intel compatibility, public release, or App Store readiness.
