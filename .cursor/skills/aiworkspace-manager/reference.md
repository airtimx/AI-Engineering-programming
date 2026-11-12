# AI Workspace Manager 参考规范

版本以 `skills/VERSION` 为准。  
**唯一规则源：本文件。** `SKILL.md`、`SKILL.global.md` 和规则文件只做入口适配，不复制细则。

## 产品边界

做：初始化 `workspace/`（兼容旧名 `codestatrFirst/`）、生成 `spec.md`/`design.md`/`tasks.md`、维护 cache、续接进度、安装/卸载/诊断 Cursor 与 Trae Skill、提供 `claim`/`release`/`who` 轻量认领。

不做：不自动修改业务代码、不自动提交、不自动创建 PR/Issue。`-SuggestCommit` 只打印建议文案。

## 统一入口

```powershell
./skills/aiws.ps1 init [-Root <项目根目录>]
./skills/aiws.ps1 new -Title "用户登录" -Requirement "手机号验证码登录" [-Priority P1] [-Owner 你] [-AsciiNames]
./skills/aiws.ps1 new -BatchFile .\skills\requirements.batch.example.txt [-ResumeBatch]
./skills/aiws.ps1 resume [-Module 登录] [-SyncCache] [-SuggestCommit] [-Json]
./skills/aiws.ps1 status [-Module 登录] [-Json]
./skills/aiws.ps1 claim -Module 登录 [-Owner 你] [-Force]
./skills/aiws.ps1 release -Module 登录 [-Owner 你] [-Force]
./skills/aiws.ps1 who [-Module 登录] [-Json]
./skills/aiws.ps1 install [-IDE All|Cursor|Trae]
./skills/aiws.ps1 uninstall [-IDE All|Cursor|Trae] -Force
./skills/aiws.ps1 doctor [-Root <项目根目录>] [-Json]
```

底层脚本继续保留，但新工作流统一走 `aiws.ps1`。

## 工作流

```text
init -> new -> 编辑 specs/<module>/tasks.md -> resume -SyncCache
```

## 目录与数据

新项目优先使用 `<项目根>/workspace/`；已有 `codestatrFirst/` 时继续兼容旧目录。

```text
workspace/
  agents/ skills/ cache/ specs/ bugfix/ .locks/ .trash/
```

`cache/<module>.json` 使用 `schema_version=1`。状态枚举：`initialized`、`in_progress`、`done`、`unknown`。可选 `owner` 字段用于轻量认领。

损坏缓存必须生成 `.bak` 并保留原文件，禁止静默覆盖。

## 根目录解析

优先级：`-Root`、`AIWORKSPACE_PROJECT_ROOT`、全局 toolkit 从 cwd 向上探测、脚本所在目录上一级。

`AIWORKSPACE_ALLOW_ANY_ROOT=1` 会关闭路径保护，只用于排错。

## 批量需求

数据行：`title|requirement|priority(optional)`。以 `#` 开头的整行始终是注释。支持 `-ResumeBatch` 从 `cache/.batch-progress.json` 续接。

## 安全约束

- 标题和需求写入 Markdown 前中和 ATX 标题与 checkbox 注入。
- 拒绝危险系统根目录、盘根和 UNC 根。
- 全局安装生成 `manifest.json`，并用 SHA256 校验文件一致性。
- 全局 manifest 漂移默认硬失败，退出码 4。
- 非交互卸载必须显式使用 `-Force`。
- `skills/*.ps1` 必须保存为 UTF-8 BOM。

## 退出码

| 码 | 含义 |
|---:|---|
| 0 | 成功 |
| 1 | 失败 |
| 2 | 用法或歧义 |
| 3 | 文件锁超时 |
| 4 | 全局 manifest 漂移 |

## 质量门禁

```powershell
./scripts/verify-local.ps1
./skills/validate-workspace.ps1 -Quiet
./skills/run-tests.ps1
./skills/analyze-workspace.ps1
```

依赖版本集中在 `skills/dependency-versions.ps1`：Pester `5.7.1`、PSScriptAnalyzer `1.25.0`。

## Skill 文件关系

| 文件 | 用途 |
|---|---|
| `.cursor/skills/aiworkspace-manager/SKILL.md` | 项目内 Cursor Skill 入口 |
| `.cursor/skills/aiworkspace-manager/SKILL.global.md` | 全局安装模板 |
| `.cursor/skills/aiworkspace-manager/reference.md` | 唯一详细规则源 |
| `skills/aiworkspace-manager.skill.md` | 旧版兼容跳转 |

全局安装：`./skills/aiws.ps1 install -IDE All`。
