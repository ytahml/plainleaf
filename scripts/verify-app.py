#!/usr/bin/env python3
"""Validate the actual ad-hoc bundle, including after ZIP extraction."""
import pathlib
import plistlib
import re
import subprocess
import sys


def verify(app, architecture):
    contents = pathlib.Path(app) / "Contents"
    info = plistlib.loads((contents / "Info.plist").read_bytes())
    assert info["LSMinimumSystemVersion"] == "15.0", "Unexpected minimum macOS"
    assert re.fullmatch(r"\d+\.\d+\.\d+", info["CFBundleShortVersionString"])
    assert re.fullmatch(r"[1-9]\d*", info["CFBundleVersion"])
    binary = contents / "MacOS" / info["CFBundleExecutable"]
    actual = subprocess.check_output(["lipo", "-archs", binary], text=True).strip()
    assert actual == architecture, f"Expected {architecture}, got {actual}"
    load_commands = subprocess.check_output(["otool", "-l", binary], text=True)
    minimums = re.findall(r"\bminos (\S+)", load_commands)
    assert minimums and all(v == "15.0" for v in minimums), minimums
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    signature = subprocess.run(["codesign", "-dv", str(app)], capture_output=True, text=True, check=True)
    assert "Signature=adhoc" in signature.stderr, "Expected ad-hoc signature"
    signed = subprocess.check_output(["codesign", "-d", "--entitlements", "-", "--xml", str(app)])
    expected = plistlib.loads((pathlib.Path(__file__).resolve().parents[1] /
                              "Sources/Plainleaf/Resources/Plainleaf.entitlements").read_bytes())
    assert plistlib.loads(signed) == expected, "Entitlements differ from source"
    resources = contents / "Resources"
    for name in [
        "AppIcon.icns", "Plainleaf_Plainleaf.bundle/Fonts/LXGWWenKaiGBLite-Regular.ttf",
        "Plainleaf_Plainleaf.bundle/Fonts/OFL.txt", "Highlighter_Highlighter.bundle/highlight.min.js",
        "Highlighter_Highlighter.bundle/flexoki-light.css", "Highlighter_Highlighter.bundle/flexoki-dark.css",
        *[f"Licenses/{name}" for name in ["Plainleaf.txt", "THIRD_PARTY_NOTICES.md",
            "swift-markdown-LICENSE.txt", "swift-markdown-NOTICE.txt", "swift-cmark-COPYING.txt",
            "HighlighterSwift.md", "highlight.js.txt", "Flexoki.txt", "LXGW-OFL.txt"]],
    ]:
        assert (resources / name).is_file() and (resources / name).stat().st_size, f"Missing {name}"
    print(f"Verified {app}: {architecture}, macOS 15.0, ad-hoc, resources and licenses")


if __name__ == "__main__":
    verify(*sys.argv[1:])
