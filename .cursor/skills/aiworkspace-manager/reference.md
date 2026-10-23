# AI Workspace — 参考（v1.4）

## cache.status

`initialized` | `in_progress` | `done` | `unknown`

## 目录

默认 `<根>/codestatrFirst/`（`AIWORKSPACE_BUNDLE_DIR` 可改）。含 `.locks/`、`.trash/`、`cache/.batch-progress.json`。

## 根解析

1. `-Root` 2. `AIWORKSPACE_PROJECT_ROOT` 3. skills 上一级  

init / auto / new-* 带 bootstrap：非危险目录即可（可有 README）。  
`AIWORKSPACE_ALLOW_ANY_ROOT=1` 危险。全局 toolkit 默认严格 manifest。

## 退出码

0 OK · 1 fail · 2 usage · 3 lock · 4 manifest

## 脚本要点

| 脚本 | 要点 |
|------|------|
| auto-requirement | `-ResumeBatch`、`-AsciiNames`、`-Json`；正文防 MD 注入 |
| resume | `-Json`；歧义前缀默认 throw；`-AllowAmbiguousPrefix` 只取第一个 |
| validate / run-tests / analyze | 质量门禁 |
