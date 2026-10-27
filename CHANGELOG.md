# Changelog

All notable changes to AI Workspace Manager (toolkit) are documented here.

## [1.5.2] - 2026-10-27

### Added
- `scripts/bootstrap-pester.ps1` — install Pester ≥5.5 for CurrentUser (side-by-side with Win 3.4).
- `scripts/verify-local.ps1` — one-shot: bootstrap → validate → Invoke-Pester `tests/` → analyzer.

### Fixed
- Exit-code contract: install/uninstall wrappers, `install-global-skill`, `run-tests`, init/new-*/auto forward or `exit 0`/`exit $LASTEXITCODE` (no stale codes).
- CI: explicit `Invoke-Pester` on `tests/` (Windows + Ubuntu) after bootstrap; not smoke-only.

### Changed
- Version **1.5.2**.

## [1.5.1] - 2026-10-24

### Fixed / hardened
- **UTF-8 BOM**: all `skills/*.ps1` must have BOM (PS 5.1); installer `Copy-AIWorkspaceScriptWithBom` always rewrites `.ps1` with BOM; validate asserts BOM.
- Collaboration: `claim-module.ps1` + `aiws claim|release|who`; resume warns on owner conflict.
- `-SuggestCommit` prints PR title/body skeleton (still does not auto commit/PR).
- `REMOTE.md` — how to attach GitHub/Origin remote for CI (no gh/Origin on some machines).

### Changed
- Version **1.5.1**.

## [1.5.0] - 2026-10-24

### Added
- Unified CLI: `skills/aiws.ps1` (`init|new|resume|status|install|uninstall|doctor`).
- `doctor-workspace.ps1` with copy-paste fix commands; dual-IDE version skew check.
- Preferred bundle dir **`workspace/`** (legacy **`codestatrFirst/`** still resolved).
- `install-global-skill.ps1` / `uninstall-global-skill.ps1` with `-IDE All|Cursor|Trae`.
- Resume: human「下一步」、Agent 提示词、模块仪表盘、`-SuggestCommit`；cache optional `owner`.
- `requirements.batch.example.txt`; batch lines starting with `#` are always comments.
- Root auto-detect from cwd when using global toolkit (interactive confirm).
- `.gitattributes` + gitignore entries for `workspace/` locks/trash/batch progress.

### Changed
- Default bundle name for new projects: `workspace` (was `codestatrFirst`).
- Old install/uninstall script names are deprecated thin wrappers.
- Version **1.5.0**.

## [1.4.1] - 2026-10-24

### Added
- Trae support: `.trae/rules/aiworkspace-p0.mdc`.
- Dual installer: `install-cursor-global-skill.ps1 -IDE Cursor|Trae` (Trae → `%USERPROFILE%\.trae-cn\skills\`); matching `uninstall -IDE`.
- CI + validate: Trae install toolkit SHA256 must match repo `skills/` (staleness guard).

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
