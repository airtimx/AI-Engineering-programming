# AI Workspace — 参考（v1.3）

## cache.status

`initialized` | `in_progress` | `done` | `unknown`

Corrupt cache → `.json.bak` kept; SyncCache will not overwrite.

## 目录（`<项目根>/codestatrFirst/`）

agents、skills、cache、specs、bugfix；`.locks/`（文件锁）、`.trash/`；根下 `项目说明.md`。

## 项目根解析

1. `-Root`（显式）
2. `AIWORKSPACE_PROJECT_ROOT`
3. 仓库内 `skills/` 的上一级（全局 toolkit **必须** 1 或 2）

不安全路径会被拒绝。

### DANGEROUS

`AIWORKSPACE_ALLOW_ANY_ROOT=1` 关闭路径防护（发布说明必标红）。设置后打印红色 SECURITY 横幅。

`AIWORKSPACE_STRICT_MANIFEST=1`：已安装 toolkit 的 SHA256 漂移则硬失败。

## 脚本

| 脚本 | 作用 |
|------|------|
| init-workspace.ps1 | 五目录 + 项目说明.md（UTF-8 无 BOM） |
| auto-requirement.ps1 | 三件套 + cache JSON（带锁） |
| new-module-spec.ps1 | 空模板三件套（带锁） |
| new-bugfix.ps1 | bugfix 记录 |
| resume-workspace.ps1 | 读 specs/cache；歧义前缀默认 throw；`-ExactModule` |
| validate-workspace.ps1 | 回归矩阵 |
| install / uninstall | 全局 Skill + manifest |

命名：`Normalize-AIWorkspaceName`。运行时：PS 5.1 / PS 7+。

## 跨设备

Git 同步整个仓库或 `codestatrFirst/`，新机器 `resume-workspace.ps1 -SyncCache`。
