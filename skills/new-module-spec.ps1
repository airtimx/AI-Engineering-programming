param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
Assert-AIWorkspaceToolkitReady -ToolkitDir $PSScriptRoot
$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot -AllowEmptyBootstrap
& (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $repoRoot
$WorkspaceBundle = Get-AIWorkspaceBundlePath -RepositoryRoot $repoRoot

if ([string]::IsNullOrWhiteSpace($ModuleName)) {
    throw "ModuleName cannot be empty or whitespace."
}

Invoke-WithAIWorkspaceLock -BundleRoot $WorkspaceBundle -LockName "specs-create" -Action {
    $displayName = Protect-AIWorkspaceMarkdownText -Value $ModuleName -Mode Inline
    $safeName = Normalize-AIWorkspaceName -Value $ModuleName
    $safeName = Get-UniqueModuleName -BaseRoot $WorkspaceBundle -Candidate $safeName

    $moduleDir = Join-Path $WorkspaceBundle (Join-Path "specs" $safeName)
    if (-not (Test-Path -LiteralPath $moduleDir)) {
        New-Item -ItemType Directory -Path $moduleDir | Out-Null
    }

    $specPath = Join-Path $moduleDir "spec.md"
    $designPath = Join-Path $moduleDir "design.md"
    $tasksPath = Join-Path $moduleDir "tasks.md"
    $createdAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    if (-not (Test-Path -LiteralPath $specPath)) {
        Write-Utf8NoBomFile -Path $specPath -Content @"
# Spec - $safeName

## Title
$displayName

## Background
- 说明为何需要本模块。

## Scope
- In scope:
- Out of scope:

## Acceptance Criteria
- [ ] 验收标准 1
- [ ] 验收标准 2
"@
    }

    if (-not (Test-Path -LiteralPath $designPath)) {
        Write-Utf8NoBomFile -Path $designPath -Content @"
# Design - $safeName

## Approach
- 概述技术方案。

## Data / API
- Inputs:
- Outputs:
- Constraints:

## Flow
1. 步骤 1
2. 步骤 2
"@
    }

    if (-not (Test-Path -LiteralPath $tasksPath)) {
        Write-Utf8NoBomFile -Path $tasksPath -Content @"
# Tasks - $safeName

> Docs generated at $createdAt (not a checklist item).

## TODO
- [ ] 任务 1
- [ ] 任务 2

## In Progress
- [ ] (none)

## Done
- [ ] (none)
"@
    }

    $progress = Get-TasksProgressSummary -TasksPath $tasksPath
    $fields = New-AIWorkspaceCacheSchema `
        -ModuleName $safeName `
        -Title $displayName `
        -Requirement "" `
        -Priority "P2" `
        -Status "initialized" `
        -OpenTodoCount $progress.Todo `
        -DoneCount $progress.Done `
        -CreatedAt $createdAt
    Write-ModuleCacheJson -BundleRoot $WorkspaceBundle -ModuleName $safeName -Fields $fields | Out-Null

    Write-Host "Module files ready in: $moduleDir"
}
