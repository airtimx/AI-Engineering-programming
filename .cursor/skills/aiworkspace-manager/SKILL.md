---
name: aiworkspace-manager
description: >-
  Initializes workspace/ (legacy codestatrFirst), writes 项目说明.md, generates
  spec/design/tasks, resumes via toolkit v1.5+. Prefer ./skills/aiws.ps1.
---

# AI Workspace Manager

精简正文以省 token；细则见 [reference.md](reference.md)。**必须终端执行脚本落盘**。

## 执行入口

优先：`./skills/aiws.ps1`（`init|new|resume|status|install|doctor`）。

| 场景 | 命令 |
|------|------|
| 本仓库 | `powershell -NoProfile -ExecutionPolicy Bypass -File "./skills/aiws.ps1" <cmd>` |
| 其它项目 / 全局 toolkit | 同上，加 `-Root "<项目绝对路径>"` |

## 工作流

```
- [ ] P0: aiws.ps1 init → workspace/ + 项目说明.md
- [ ] P1: aiws.ps1 new → specs 三件套 + cache
- [ ] 勾选 tasks.md → aiws.ps1 resume -SyncCache
- [ ] 再写业务代码
```
