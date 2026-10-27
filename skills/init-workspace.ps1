<#
.SYNOPSIS
Create workspace bundle (preferred name) + 项目说明.md under the project root.
Legacy folder codestatrFirst is reused if already present.
#>
param(
    [string]$Root = ".",
    [switch]$ForceDoc
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")

Assert-AIWorkspaceToolkitReady -ToolkitDir $PSScriptRoot

# Empty dirs are allowed here so init can bootstrap a brand-new project folder
$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot -AllowEmptyBootstrap
$bundleRoot = Get-AIWorkspaceBundlePath -RepositoryRoot $repoRoot
$bundleName = Resolve-AIWorkspaceBundleDirName -RepositoryRoot $repoRoot
$ver = Get-AIWorkspaceToolkitVersion

Write-Host "Toolkit version:  $ver"
Write-Host "Repository root:  $repoRoot"
Write-Host "Workspace bundle: $bundleRoot"

if (-not (Test-Path -LiteralPath $bundleRoot)) {
    New-Item -ItemType Directory -Path $bundleRoot | Out-Null
    Write-Host "Created bundle: $bundleRoot"
}
else {
    Write-Host "Bundle exists: $bundleRoot"
}

Ensure-AIWorkspaceGitkeeps -BundleRoot $bundleRoot
foreach ($folder in @("agents", "skills", "cache", "specs", "bugfix")) {
    Write-Host "Ready:  $(Join-Path $bundleRoot $folder)"
}

# Exact whitelist only → move to .trash/ (never broad delete)
[void](Clear-AIWorkspaceGarbledDocs -BundleRoot $bundleRoot)

$docPath = Join-Path $bundleRoot (Get-AIWorkspaceProjectDocFileName)
$shouldWriteDoc = $ForceDoc -or -not (Test-Path -LiteralPath $docPath)
if (-not $shouldWriteDoc) {
    Write-Host "Exists:  $docPath (skip rewrite; use -ForceDoc to refresh)"
}
else {
    $doc = @"
# 项目说明（AI Workspace）

本文件在 **创建/校验 ``$bundleName`` 下五目录之后生成**。请勿删除本段约定。

## 元数据

| 项 | 值 |
|----|----|
| Toolkit 版本 | $ver |
| 仓库根（相对） | `.` |
| 工作区捆（相对） | ``$bundleName`` |

## 目录用途

| 目录 | 用途 |
|------|------|
| agents/ | Agent 定义与说明 |
| skills/ | 工作区内 AI Skill 规则 |
| cache/ | JSON 缓存（schema_version=1；可选 owner） |
| specs/ | spec.md / design.md / tasks.md |
| bugfix/ | 修复记录 |
| .trash/ | init 移入的历史乱码文件（勿当业务数据） |

## cache.status 枚举

``initialized`` | ``in_progress`` | ``done`` | ``unknown``

## 常用命令

- ``./skills/aiws.ps1 init``
- ``./skills/aiws.ps1 new -Title "..." -Requirement "..."``
- ``./skills/aiws.ps1 resume -SyncCache``
- ``./skills/aiws.ps1 doctor``

## 跨设备

1. ``git init``（若尚无仓库）并提交整个项目（含 ``$bundleName/specs/**`` 与 ``$bundleName/cache/*.json``）
2. 其它电脑 ``git pull`` 后执行 ``./skills/aiws.ps1 resume -SyncCache``
3. **勿只拷贝 cache/**；specs 与 cache 应一起进版本库
"@
    Write-Utf8NoBomFile -Path $docPath -Content $doc
    Write-Host "Written: $docPath"
}

Write-Host ""
Write-Host "Workspace initialization completed."
exit 0
