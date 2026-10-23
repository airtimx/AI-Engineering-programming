# Changelog

All notable changes to AI Workspace Manager (toolkit) are documented here.

## [1.4.0] - 2026-10-24

### Added
- Batch resume: `-ResumeBatch` + `cache/.batch-progress.json` (non-atomic → continuable).
- `-Json` on resume; exit codes 0/1/2/3/4; `Set-StrictMode` with PS5 `$IsLinux` guards.
- `-AsciiNames` / `AIWORKSPACE_ASCII_NAMES=1`; bundle dir override `AIWORKSPACE_BUNDLE_DIR`.
- `analyze-workspace.ps1` + CI PSScriptAnalyzer step.
- Global toolkit: strict manifest by default (disable with `AIWORKSPACE_STRICT_MANIFEST=0`).
- Nested-lock avoidance: cache write skips lock when `specs-create` already held.
- init bootstrap: any non-forbidden dir (README/src OK), not only empty.

### Changed
- `-AllowAmbiguousPrefix` picks **first** match only (no multi-module dump).
- Uninstall non-interactive requires `-Force`.
- Version **1.4.0**.

## [1.3.2] - 2026-10-24

### Fixed
- Markdown injection: Title/Requirement sanitized (`Protect-AIWorkspaceMarkdownText`) before writing specs.
- INFO/WARN use `Write-Information` / `Write-Warning` (capturable via `6>&1` / `3>&1` on PS 5.1).
- Batch comments: `#` alone or `# ` (hash+space); `#title|req` without space remains data.
- Documented uniquify: same title → `name-2` + warning; README updated.
- Local Pester: `skills/run-tests.ps1` installs/imports Pester 5 alongside Windows 3.4.

## [1.3.1] - 2026-10-23

### Fixed
- Task progress skips fenced `` ``` `` / `~~~` blocks (no longer counts example `- [ ]`).
- `new-bugfix` appends `## Follow-up` on same-day same title instead of silent exit.
- `init-workspace` allows brand-new **empty** directories (`-AllowEmptyBootstrap`).
- `resume -SyncCache` WARNs and displays corrected priority/status (e.g. P9→P2).
- Batch lines: `# comment` skipped; `#title|req|P1` kept.
- Removed unused `Read-ModuleCacheJson -NoOverwriteOnError`; `new-bugfix` calls toolkit ready check.

## [1.3.0] - 2026-10-23

### Added
- File locks under `codestatrFirst/.locks/` for cache writes and module creation (concurrency-safe).
- `AIWORKSPACE_STRICT_MANIFEST=1` / `Test-AIWorkspaceManifest -Strict` hard-fail on hash drift.
- Cross-platform home/path helpers (`Get-AIWorkspaceHomeDirectory`, portable `Join-Path`); PS 5.1 + PS 7.
- Loud **SECURITY** banner when `AIWORKSPACE_ALLOW_ANY_ROOT=1`.
- Pester tests (`tests/`), GitHub Actions CI (Windows full + Ubuntu pwsh smoke).
- `CHANGELOG.md`, `LICENSE` (MIT), `RELEASE.md` publish checklist.
- `resume-workspace.ps1`: ambiguous prefix throws unless `-ExactModule` / `-AllowAmbiguousPrefix`.
- `uninstall-cursor-global-skill.ps1 -SkillRoot` for testable uninstall.

### Changed
- Toolkit version **1.3.0**; install writes runtime note into `manifest.json`.
- validate matrix covers lock contention, manifest Strict, uninstall, ambiguous modules.

## [1.2.0] - 2026-10-23

### Fixed
- Data-loss defects (garbled-doc whitelist + trash, corrupt cache bak, path safety, batch `|`, UTF-8).
- Global install consistency via SHA256 `manifest.json`.
- Status/progress schema and checkbox parsing.
