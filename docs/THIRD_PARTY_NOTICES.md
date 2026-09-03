# Third-party notices

Plainleaf currently declares these Swift Package dependencies:

- `swiftlang/swift-markdown` — Apache License 2.0 with Swift runtime library exception. Its distribution includes `swift-cmark`, derived from `cmark-gfm`.
- `smittytone/HighlighterSwift` 3.1.0 — MIT License. It bundles `highlight.js`, distributed under the BSD 3-Clause License. Plainleaf vendors this fixed version in `Vendor/HighlighterSwift` and carries a narrow resource-location patch so its SwiftPM bundle can live in the standard macOS application resources directory.
- `kepano/flexoki` — MIT License, copyright Steph Ango. Plainleaf adapts its palette for local syntax-highlighting styles. The upstream license is retained in `Vendor/Flexoki/LICENSE`.
- `lxgw/LxgwWenkaiGB-Lite` v1.522 — SIL Open Font License 1.1. Plainleaf bundles `LXGWWenKaiGBLite-Regular.ttf` for offline reading typography. The shipped font SHA-256 is `1675c708cce181871d9a8adc987f35a0cabc6ff980685cd99f05d2655ea08c4c`; the upstream license is retained beside it in `Sources/Plainleaf/Resources/Fonts/OFL.txt`.

Release packaging must retain the exact upstream license and notice files resolved for the shipped dependency versions. This summary is not a substitute for those files.
