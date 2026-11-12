---
name: aiworkspace-manager
description: >-
  Project-local AI Workspace Manager skill. Use ./skills/aiws.ps1 to initialize workspace/,
  create specs, resume progress, and diagnose the toolkit.
---

# AI Workspace Manager

详细规则唯一来源：[reference.md](reference.md)。本文件只定义当前项目的执行入口。

## 执行入口

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "./skills/aiws.ps1" <command>
```

优先命令：`init`、`new`、`resume`、`status`、`claim`、`release`、`who`、`install`、`uninstall`、`doctor`。

## 工作流

```text
aiws init -> aiws new -> 编辑 workspace/specs/<module>/tasks.md -> aiws resume -SyncCache
```

不要伪造已创建的工作区文件；必须通过终端执行脚本落盘。不要自动修改业务代码或创建 Git 提交/PR。
