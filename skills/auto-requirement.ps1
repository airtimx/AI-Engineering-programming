param(
    [string]$Title,
    [string]$Requirement,
    [string]$BatchFile,
    [ValidateSet("P0", "P1", "P2", "P3")]
    [string]$Priority = "P2",
    [string]$Root = ".",
    [switch]$ForceDoc
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
Assert-AIWorkspaceToolkitReady -ToolkitDir $PSScriptRoot

$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot

# init once (skip rewriting 项目说明 unless -ForceDoc)
if ($ForceDoc) {
    & (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $repoRoot -ForceDoc
}
else {
    & (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $repoRoot
}
$WorkspaceBundle = Get-AIWorkspaceBundlePath -RepositoryRoot $repoRoot

function New-RequirementModule {
    param(
        [string]$InputTitle,
        [string]$InputRequirement,
        [string]$InputPriority,
        [string]$BaseRoot
    )

    if ([string]::IsNullOrWhiteSpace($InputTitle) -or [string]::IsNullOrWhiteSpace($InputRequirement)) {
        throw "Title and Requirement are required for each item."
    }

    return Invoke-WithAIWorkspaceLock -BundleRoot $BaseRoot -LockName "specs-create" -Action {
    $createdAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $moduleName = Normalize-AIWorkspaceName -Value $InputTitle
    $moduleName = Get-UniqueModuleName -BaseRoot $BaseRoot -Candidate $moduleName

    $moduleDir = Join-Path $BaseRoot (Join-Path "specs" $moduleName)
    New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

    $specPath = Join-Path $moduleDir "spec.md"
    $designPath = Join-Path $moduleDir "design.md"
    $tasksPath = Join-Path $moduleDir "tasks.md"

    $spec = @"
# Spec - $moduleName

## Title
$InputTitle

## Background
- $InputRequirement

## Scope
- In scope:
  - 实现标题与需求描述中的核心能力
- Out of scope:
  - 未在本需求中明确写出的扩展项

## Acceptance Criteria
- [ ] 行为与需求描述一致，主流程可演示
- [ ] 关键边界与异常路径已在 design.md 中说明
- [ ] tasks.md 中任务可执行且可勾选验收
"@

    $design = @"
# Design - $moduleName

## Approach
- 以 spec.md 的范围为准，先交付可运行的最小方案，再按反馈迭代。
- 优先复用本仓库 ``codestatrFirst`` 约定。

## Data / API
- Inputs:
  - 用户需求：$InputRequirement
- Outputs:
  - 可验证的功能行为 + 更新后的 specs/tasks
- Constraints:
  - 不破坏 ``codestatrFirst`` 结构；落盘 UTF-8 无 BOM

## Flow
1. 确认边界与验收标准
2. 实现最小可用方案并更新 tasks 状态
3. 按验收标准自测
"@

    # Docs-generated note is PLAIN TEXT (not [x]) so status stays initialized until real work is checked
    $tasks = @"
# Tasks - $moduleName

> Docs generated at $createdAt (not a checklist item).

## TODO
- [ ] 与用户确认边界与异常路径
- [ ] 实现核心功能代码
- [ ] 补充或更新测试
- [ ] 按 Acceptance Criteria 验收并勾选

## In Progress
- [ ] (none)

## Done
- [ ] (none)
"@

    Write-Utf8NoBomFile -Path $specPath -Content $spec
    Write-Utf8NoBomFile -Path $designPath -Content $design
    Write-Utf8NoBomFile -Path $tasksPath -Content $tasks

    $progress = Get-TasksProgressSummary -TasksPath $tasksPath
    $fields = New-AIWorkspaceCacheSchema `
        -ModuleName $moduleName `
        -Title $InputTitle `
        -Requirement $InputRequirement `
        -Priority $InputPriority `
        -Status "initialized" `
        -OpenTodoCount $progress.Todo `
        -DoneCount $progress.Done `
        -CreatedAt $createdAt
    $cacheFile = Write-ModuleCacheJson -BundleRoot $BaseRoot -ModuleName $moduleName -Fields $fields

    Write-Host "Module ready: $moduleName"
    Write-Host "Specs:        $moduleDir"
    Write-Host "Cache:        $cacheFile"
    }
}

function Parse-BatchItems {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Batch file not found: $Path"
    }

    $raw = Read-Utf8File -Path $Path -Strict
    $lines = $raw -split "`r?`n"
    $items = @()
    $lineNo = 0

    foreach ($rawLine in $lines) {
        $lineNo++
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        # title|requirement...|optionalPriority — if last field is P0-P3, treat as priority; middle joins with |
        $parts = $line.Split([char]('|'))
        if ($parts.Count -lt 2) {
            throw "Invalid batch line $lineNo : $line`nExpected: title|requirement|priority(optional)"
        }

        $itemTitle = $parts[0].Trim()
        $itemPriority = $Priority
        $itemRequirement = $null

        if ($parts.Count -eq 2) {
            $itemRequirement = $parts[1].Trim()
        }
        else {
            $last = $parts[$parts.Count - 1].Trim().ToUpper()
            if ($last -in @("P0", "P1", "P2", "P3")) {
                $itemPriority = $last
                $itemRequirement = ($parts[1..($parts.Count - 2)] -join "|").Trim()
            }
            else {
                $itemRequirement = ($parts[1..($parts.Count - 1)] -join "|").Trim()
            }
        }

        if ([string]::IsNullOrWhiteSpace($itemTitle) -or [string]::IsNullOrWhiteSpace($itemRequirement)) {
            throw "Empty title/requirement at batch line $lineNo"
        }

        $items += [pscustomobject]@{
            Title       = $itemTitle
            Requirement = $itemRequirement
            Priority    = $itemPriority
        }
    }

    return $items
}

if (-not [string]::IsNullOrWhiteSpace($BatchFile)) {
    if (-not [string]::IsNullOrWhiteSpace($Title) -or -not [string]::IsNullOrWhiteSpace($Requirement)) {
        Write-Host "WARN: -Title/-Requirement ignored when -BatchFile is set."
    }
    if (-not [System.IO.Path]::IsPathRooted($BatchFile)) {
        $rel = ($BatchFile.Trim() -replace '^[/\\]+', '') -replace '^\.[/\\]+', ''
        $BatchFile = Join-Path $repoRoot $rel
    }

    $batchItems = Parse-BatchItems -Path $BatchFile
    if ($batchItems.Count -eq 0) {
        throw "Batch file has no valid items."
    }

    Write-Host "Processing batch items: $($batchItems.Count)"
    foreach ($item in $batchItems) {
        New-RequirementModule -InputTitle $item.Title -InputRequirement $item.Requirement -InputPriority $item.Priority -BaseRoot $WorkspaceBundle
    }
    Write-Host "Batch mode completed."
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = Read-Host "Input requirement title"
}
if ([string]::IsNullOrWhiteSpace($Requirement)) {
    $Requirement = Read-Host "Input requirement detail"
}
if ([string]::IsNullOrWhiteSpace($Title) -or [string]::IsNullOrWhiteSpace($Requirement)) {
    throw "Title and Requirement are required."
}

New-RequirementModule -InputTitle $Title -InputRequirement $Requirement -InputPriority $Priority -BaseRoot $WorkspaceBundle
Write-Host "Auto mode completed."
