# Release checklist (AI Workspace Manager)

## DANGEROUS escape hatch (must document every release)

> **`AIWORKSPACE_ALLOW_ANY_ROOT=1` disables path safeguards**. Default: unset.

## Global install drift

> Global toolkit **hard-fails** on manifest mismatch (exit 4) unless `AIWORKSPACE_STRICT_MANIFEST=0`.  
> Prefer `./skills/aiws.ps1 install -IDE All` so Cursor/Trae stay aligned.

> **`manifest.json`** is **generated at install time** into the target `toolkit/` (Cursor/Trae). It is **not** a file checked into this repository.

## Pre-release

- [ ] Bump `skills/VERSION`
- [ ] Update `CHANGELOG.md`
- [ ] Align README / 使用说明 / reference.md
- [ ] `./scripts/verify-local.ps1` → 0（或分步 validate -Quiet / run-tests / analyze）
- [ ] `./skills/aiws.ps1 doctor` clean on a sample project
- [ ] 所有 `.ps1`（`skills/*` 与 `scripts/*`）为 UTF-8 BOM；含中文的脚本缺 BOM 会让 PS 5.1 解析失败（`validate` 覆盖 `skills/*`）
- [ ] `git remote -v` configured (see REMOTE.md) and CI green（含 Invoke-Pester tests/）

## Git

```powershell
git tag -a v1.5.3 -m "toolkit 1.5.3"
git push origin main --tags
```

If no remote yet: create GitHub/Origin repo, then `git remote add origin <url>` and push.

推送 tag 会触发 Release 工作流：`./scripts/build-release.ps1 -ExpectedVersion <tag>` → `dist/AIWorkspaceManager-<版本>.zip` + `.sha256` → `gh release create`。本地等价自测：`./scripts/build-release.ps1 -ExpectedVersion v1.5.3`。

## Support matrix

| Runtime | Status |
|---------|--------|
| Windows PowerShell 5.1 | Supported (primary / first-party) |
| PowerShell 7+ Windows | Supported |
| PowerShell 7+ Linux/macOS | **Smoke only** (CI path helpers + validate -SkipWriteTest); not first-party parity |
| Cursor / Trae Skill | Chat triggers; CLI via `aiws.ps1` alone |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | OK |
| 1 | Fail |
| 2 | Usage / ambiguous |
| 3 | Lock timeout |
| 4 | Global manifest drift |

All entry scripts and deprecated wrappers must `exit 0` on success or `exit $LASTEXITCODE` when forwarding.
