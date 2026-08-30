# Third-party notices

Plainleaf currently declares these Swift Package dependencies:

- `swiftlang/swift-markdown` — Apache License 2.0 with Swift runtime library exception. Its distribution includes `swift-cmark`, derived from `cmark-gfm`.
- `smittytone/HighlighterSwift` 3.1.0 — MIT License. It bundles `highlight.js`, distributed under the BSD 3-Clause License. Plainleaf vendors this fixed version in `Vendor/HighlighterSwift` and carries a narrow resource-location patch so its SwiftPM bundle can live in the standard macOS application resources directory.

Release packaging must retain the exact upstream license and notice files resolved for the shipped dependency versions. This summary is not a substitute for those files.
