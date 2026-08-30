# Plainleaf agent instructions

- Plainleaf supports macOS 15 and must remain runnable on the maintainer's macOS 15.7 system. Do not introduce macOS 26-only APIs without a macOS 15 fallback.
- User Markdown files are the source of truth. Never create hidden metadata inside an opened workspace.
- Do not overwrite an externally modified document. Detect the conflict and require an explicit user choice.
- Do not add telemetry, background network access, cloud sync, AI features, or remote publication without explicit approval.
- Do not add permanent-delete behavior. Any future delete action must use the macOS Trash and require separate product approval.
- Keep project-specific decisions in `.codex/memories/PROJECT_MEMORY.md`, not in global memory.
- Keep implementation, automated checks, manual acceptance, packaging, and publication status separate in reports.
