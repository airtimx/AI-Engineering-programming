---
name: aiworkspace-manager
description: >-
  Initializes workspace/ (legacy codestatrFirst) with agents/skills/cache/specs/bugfix,
  writes 项目说明.md, generates spec/design/tasks, and resumes via PowerShell toolkit v1.5+.
  Use in any Cursor or Trae project for init, new module, auto-requirement, bugfix, resume,
  doctor, or AIWorkspace conventions. Prefer aiws.ps1 unified CLI.
---

# AI Workspace Manager（全局）

路径：`%USERPROFILE%\.cursor\skills\aiworkspace-manager\`。细则见 [reference.md](reference.md)。

**必须**对当前工作区传 `-Root "<项目根>"`（或设 `AIWORKSPACE_PROJECT_ROOT`；从 cwd 也可探测）。

## 工具包

`%USERPROFILE%\.cursor\skills\aiworkspace-manager\toolkit\`

```powershell
$tk = "$env:USERPROFILE\.cursor\skills\aiworkspace-manager\toolkit"
powershell -NoProfile -ExecutionPolicy Bypass -File "$tk\aiws.ps1" init -Root "<项目根>"
powershell -NoProfile -ExecutionPolicy Bypass -File "$tk\aiws.ps1" new -Root "<项目根>" -Title "<标题>" -Requirement "<描述>" -Priority P1
powershell -NoProfile -ExecutionPolicy Bypass -File "$tk\aiws.ps1" resume -Root "<项目根>" -SyncCache
powershell -NoProfile -ExecutionPolicy Bypass -File "$tk\aiws.ps1" doctor -Root "<项目根>"
```

## 工作流

P0 init → P1 specs/cache → 勾选 tasks → resume 续接 → 再写代码。文档在 `workspace/`（或旧名 `codestatrFirst/`）。

## 更新

模板仓：`.\skills\install-global-skill.ps1 -IDE All`（或 `-IDE Cursor` / `-IDE Trae`）
