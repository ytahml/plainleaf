# Plainleaf MVP product specification

## Core flow

1. Open a folder through the macOS folder picker.
2. Browse its non-hidden directory structure and supported Markdown files.
3. Select a document and edit its Markdown source.
4. Let Plainleaf save changes atomically without hiding failures.
5. Toggle the same document into a carefully typeset reading mode.
6. Quit and reopen Plainleaf with the last authorized workspace and state restored.

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

- Headings, paragraphs, emphasis, strong text, strike-through, inline code
- Ordered and unordered lists, task lists, block quotes, thematic breaks
- GFM tables
- Fenced code with local syntax highlighting
- Local images resolved relative to the current document
- Relative Markdown links open inside Plainleaf; web links open in the default browser
- Raw HTML is shown as source text and is never executed
- Remote images are represented by a privacy placeholder and are never fetched automatically

## Visual language

- Paper: pressed-fiber desk, pale rice-paper surfaces, graphite text, fern accent, and a restrained copper warning color
- Ink: deep green-charcoal desk and surfaces, soft ivory text, adjusted fern, and warm copper
- UI: SF Pro; source and utility labels: SF Mono; reading: New York; code: SF Mono
- One collapsible library sidebar, one centered paper surface, a document header, and a quiet toolbar
- The selected-file bookmark and the reading-mode heading rule share a leaf-vein motif
- Theme follows the system by default and can be fixed to Paper or Ink

## Data and privacy

- No network requests initiated by Plainleaf
- No telemetry or crash uploads
- No application metadata written into user workspaces
- Security-scoped bookmarks are stored in local application preferences
- External file changes are reloaded only when safe; conflicting changes stop autosave
