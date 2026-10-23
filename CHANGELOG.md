# Changelog

All notable changes to AI Workspace Manager (toolkit) are documented here.

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
