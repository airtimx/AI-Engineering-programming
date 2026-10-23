# Release checklist (AI Workspace Manager)

## DANGEROUS escape hatch (must document every release)

> **`AIWORKSPACE_ALLOW_ANY_ROOT=1` disables path safeguards**. Default: unset.

## Global install drift

> Global toolkit **hard-fails** on manifest mismatch (exit 4) unless `AIWORKSPACE_STRICT_MANIFEST=0`.

## Pre-release

- [ ] Bump `skills/VERSION`
- [ ] Update `CHANGELOG.md`
- [ ] Align README / 使用说明 / reference.md
- [ ] `./skills/validate-workspace.ps1` → 0
- [ ] `./skills/run-tests.ps1` → 0
- [ ] `./skills/analyze-workspace.ps1` → 0
- [ ] CI green

## Git

```powershell
git tag -a v1.4.0 -m "toolkit 1.4.0"
git push origin main --tags
```

If no remote yet: create GitHub/Origin repo, then `git remote add origin <url>` and push.

## Support matrix

| Runtime | Status |
|---------|--------|
| Windows PowerShell 5.1 | Supported (primary) |
| PowerShell 7+ Windows | Supported |
| PowerShell 7+ Linux/macOS | Best-effort |
| Cursor Skill | Required for chat triggers; CLI works alone |

## Exit codes

0 OK · 1 fail · 2 usage · 3 lock · 4 manifest
