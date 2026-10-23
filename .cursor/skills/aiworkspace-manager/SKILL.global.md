---
name: aiworkspace-manager
description: >-
  Initializes codestatrFirst workspace (agents/skills/cache/specs/bugfix),
  writes 项目说明.md, generates spec/design/tasks, and resumes work via global
  PowerShell toolkit v1.3+. Use in any Cursor project for init workspace, new module,
  auto-requirement, bugfix, resume, or AIWorkspace conventions.
---

# AI Workspace Manager（全局）

路径：`%USERPROFILE%\.cursor\skills\aiworkspace-manager\`。细则见 [reference.md](reference.md)。

**必须**对当前工作区传 `-Root "<项目根>"`（或设 `AIWORKSPACE_PROJECT_ROOT`）。

## 工具包

`%USERPROFILE%\.cursor\skills\aiworkspace-manager\toolkit\`

```powershell
$tk = "$env:USERPROFILE\.cursor\skills\aiworkspace-manager\toolkit"
powershell -NoProfile -ExecutionPolicy Bypass -File "$tk\init-workspace.ps1" -Root "<项目根>"
powershell -NoProfile -ExecutionPolicy Bypass -File "$tk\auto-requirement.ps1" -Root "<项目根>" -Title "<标题>" -Requirement "<描述>" -Priority P1
powershell -NoProfile -ExecutionPolicy Bypass -File "$tk\resume-workspace.ps1" -Root "<项目根>" -SyncCache
powershell -NoProfile -ExecutionPolicy Bypass -File "$tk\validate-workspace.ps1" -Root "<项目根>" -SkipWriteTest
```

## 工作流

P0 init → P1 specs/cache → resume 续接 → 再写代码。文档只写在 `codestatrFirst/`。

## 更新

模板仓执行：`.\skills\install-cursor-global-skill.ps1`
