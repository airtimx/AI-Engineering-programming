---
name: aiworkspace-manager
description: >-
  Initializes codestatrFirst workspace (agents/skills/cache/specs/bugfix),
  writes 项目说明.md, generates spec/design/tasks, and resumes cross-device work
  via PowerShell toolkit v1.3+. Use for init workspace, codestatrFirst, new module,
  auto-requirement, bugfix, resume, or AIWorkspace conventions.
---

# AI Workspace Manager

精简正文以省 token；细则见 [reference.md](reference.md)。**必须终端执行脚本落盘**。

## 执行入口

| 场景 | 命令 |
|------|------|
| 本仓库 | `powershell -NoProfile -ExecutionPolicy Bypass -File "./skills/<script>.ps1"` |
| 其它项目 / 全局 toolkit | 同上，加 `-Root "<项目绝对路径>"` |

全局 toolkit：`%USERPROFILE%\.cursor\skills\aiworkspace-manager\toolkit\`

## 工作流

```
- [ ] P0: init-workspace.ps1 → codestatrFirst/ + 项目说明.md
- [ ] P1: auto-requirement / new-module-spec → specs 三件套 + cache JSON
- [ ] 跨设备续接: resume-workspace.ps1 [-SyncCache]
- [ ] 再写业务代码
```

### 常用命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "./skills/init-workspace.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "./skills/auto-requirement.ps1" -Title "<标题>" -Requirement "<描述>" -Priority P1
powershell -NoProfile -ExecutionPolicy Bypass -File "./skills/resume-workspace.ps1" -SyncCache
powershell -NoProfile -ExecutionPolicy Bypass -File "./skills/validate-workspace.ps1"
```

## 触发短语

初始化工作区、codestatrFirst、五目录、新建模块、三件套、auto-requirement、记 bugfix、续接、resume。

## 禁止

- 无终端/写盘权限时声称已落盘
- 在仓库根再写旧的 agents/specs（一律 `codestatrFirst/`）
- 未完成 P0 前只把需求留在聊天（用户要求仅口头除外）

## 编码

落盘 UTF-8 **无 BOM**（`Write-Utf8NoBomFile`）。
