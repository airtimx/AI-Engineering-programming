# AI Workspace — 参考（v1.5.1）

## 入口

优先：`./skills/aiws.ps1`（`init|new|resume|status|claim|release|who|install|doctor`）。

产品边界：脚手架 + Skill；不自动改业务代码 / 不开 PR（`-SuggestCommit` 只打印）。

## cache.status

`initialized` | `in_progress` | `done` | `unknown`

可选字段：`owner`（`-Owner` / `AIWORKSPACE_OWNER`）。

## 目录

新项目默认 `<根>/workspace/`；若已有 `codestatrFirst/` 则继续用它。  
`AIWORKSPACE_BUNDLE_DIR` 可强制改名。含 `.locks/`、`.trash/`、`cache/.batch-progress.json`。

## 根解析

1. `-Root` 2. `AIWORKSPACE_PROJECT_ROOT` 3. 全局 toolkit 时从 cwd 向上探测（交互确认）  
4. 否则 skills 上一级  

init / auto / new-* 带 bootstrap：非危险目录即可。  
`AIWORKSPACE_ALLOW_ANY_ROOT=1` 危险。全局 toolkit 默认严格 manifest。

## 退出码

0 OK · 1 fail · 2 usage · 3 lock · 4 manifest

## 脚本要点

| 脚本 | 要点 |
|------|------|
| aiws.ps1 | 统一入口 |
| doctor-workspace | 双端版本/manifest/Root；打印可复制修复命令 |
| install-global-skill | `-IDE All\|Cursor\|Trae` |
| auto-requirement | 批量：`#` 行全是注释；示例见 `requirements.batch.example.txt` |
| resume | 仪表盘、下一步人话、Agent 提示词、`-SuggestCommit` |
