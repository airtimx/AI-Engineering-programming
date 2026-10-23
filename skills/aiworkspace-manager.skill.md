# AIWorkspace Manager Skill (v1.3)

## Trigger

Cursor 已授终端/写盘时，命中初始化、三件套、bugfix、resume 等短语，或触及 `codestatrFirst/`，按 P0→P1 落盘。

## When to run

编码/排错/规格化先 P0；新需求再 P1；跨设备先 `resume-workspace.ps1`。

## Activation Rules

1. 无权限不虚构落盘。  
2. 业务只写 `codestatrFirst/`。  
3. 损坏 cache 不得静默覆盖（`.bak` + 跳过 SyncCache）。

## cache.status

`initialized` | `in_progress` | `done` | `unknown`（schema_version=1）

## 命令

- `init-workspace.ps1`（`-ForceDoc` 强制重写项目说明）  
- `auto-requirement.ps1` / `new-module-spec.ps1` / `new-bugfix.ps1`  
- `resume-workspace.ps1 [-SyncCache] [-ExactModule]`  
- `validate-workspace.ps1`  
- `install-cursor-global-skill.ps1` / `uninstall-cursor-global-skill.ps1`  

全局安装须从**模板仓库**运行；toolkit 内含 `manifest.json`（SHA256）。
