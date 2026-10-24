# Release checklist (AI Workspace Manager)

## DANGEROUS escape hatch (must document every release)

> **`AIWORKSPACE_ALLOW_ANY_ROOT=1` disables path safeguards**. Default: unset.

## Global install drift

> Global toolkit **hard-fails** on manifest mismatch (exit 4) unless `AIWORKSPACE_STRICT_MANIFEST=0`.  
> Prefer `./skills/aiws.ps1 install -IDE All` so Cursor/Trae stay aligned.

## Pre-release

- [ ] Bump `skills/VERSION`
- [ ] Update `CHANGELOG.md`
- [ ] Align README / 使用说明 / reference.md
- [ ] `./skills/validate-workspace.ps1` → 0
- [ ] `./skills/run-tests.ps1` → 0
- [ ] `./skills/analyze-workspace.ps1` → 0
- [ ] `./skills/aiws.ps1 doctor` clean on a sample project
- [ ] All `skills/*.ps1` have UTF-8 BOM (`validate` checks)
- [ ] `git remote -v` configured (see REMOTE.md) and CI green

## Git

```powershell
git tag -a v1.5.1 -m "toolkit 1.5.1"
git push origin main --tags
```

If no remote yet: create GitHub/Origin repo, then `git remote add origin <url>` and push.

## Support matrix

| Runtime | Status |
|---------|--------|
| Windows PowerShell 5.1 | Supported (primary) |
| PowerShell 7+ Windows | Supported |
| PowerShell 7+ Linux/macOS | Supported (CI path helpers + validate smoke) |
| Cursor / Trae Skill | Chat triggers; CLI via `aiws.ps1` alone |

## Exit codes

0 OK · 1 fail · 2 usage · 3 lock · 4 manifest
