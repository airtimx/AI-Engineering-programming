# Release checklist (AI Workspace Manager)

## DANGEROUS escape hatch (must document every release)

> **`AIWORKSPACE_ALLOW_ANY_ROOT=1` disables path safeguards** (drive roots, system dirs, project-shape checks, UNC refusal).  
> Only set for controlled recovery. Default: unset. Releases must call this out in README + CHANGELOG.

## Pre-release

- [ ] Bump `skills/VERSION` (semver)
- [ ] Update `CHANGELOG.md` with Added/Changed/Fixed
- [ ] Align README / 使用说明 / `.cursor/skills/.../reference.md` version strings
- [ ] `./skills/validate-workspace.ps1` exits 0
- [ ] Pester: `Invoke-Pester ./tests` (Pester 5+)
- [ ] CI green on `main` (Windows + Ubuntu jobs)

## Publish artifacts

| Artifact | Path | Notes |
|----------|------|-------|
| Toolkit scripts | `skills/*.ps1` + `VERSION` | Source of truth |
| Cursor project skill | `.cursor/skills/aiworkspace-manager/` | SKILL.md + reference |
| Global install template | `SKILL.global.md` | Copied by installer |
| License | `LICENSE` | MIT |
| Changelog | `CHANGELOG.md` | Required for audit |

## Install / verify

```powershell
# From this repository only (not from ~/.cursor/.../toolkit)
./skills/install-cursor-global-skill.ps1
# Optional hard-fail on drift after install:
$env:AIWORKSPACE_STRICT_MANIFEST = "1"
```

Confirm `~/.cursor/skills/aiworkspace-manager/toolkit/manifest.json` version matches `skills/VERSION`.

## Git tag

```powershell
git tag -a v1.3.0 -m "toolkit 1.3.0"
git push origin v1.3.0
```

## Support matrix

| Runtime | Status |
|---------|--------|
| Windows PowerShell 5.1 | Supported (primary) |
| PowerShell 7+ Windows | Supported |
| PowerShell 7+ Linux/macOS | Best-effort (CI smoke); Cursor global path uses `$HOME/.cursor` |
