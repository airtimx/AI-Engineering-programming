param(
    [string]$Title,
    [string]$Requirement,
    [string]$BatchFile,
    [ValidateSet("P0", "P1", "P2", "P3")]
    [string]$Priority = "P2",
    [string]$Root = ".",
    [switch]$ForceDoc,
    [switch]$AsciiNames,
    [switch]$ResumeBatch,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
Assert-AIWorkspaceToolkitReady -ToolkitDir $PSScriptRoot

# Allow bootstrap so dirs with README/src (but no .git yet) can be initialized
$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot -AllowEmptyBootstrap

# init once (skip rewriting 项目说明 unless -ForceDoc)
if ($ForceDoc) {
    & (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $repoRoot -ForceDoc
}
else {
    & (Join-Path $PSScriptRoot "init-workspace.ps1") -Root $repoRoot
}
$WorkspaceBundle = Get-AIWorkspaceBundlePath -RepositoryRoot $repoRoot

function New-RequirementModule {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "Medium")]
    param(
        [string]$InputTitle,
        [string]$InputRequirement,
        [string]$InputPriority,
        [string]$BaseRoot,
        [switch]$AsciiNames
    )

    if ([string]::IsNullOrWhiteSpace($InputTitle) -or [string]::IsNullOrWhiteSpace($InputRequirement)) {
        throw "Title and Requirement are required for each item."
    }

    $useAsciiNames = [bool]$AsciiNames
    $priorityValue = $InputPriority
    if (-not $PSCmdlet.ShouldProcess($InputTitle, "Create requirement module under $BaseRoot")) {
        return
    }

    Invoke-WithAIWorkspaceLock -BundleRoot $BaseRoot -LockName "specs-create" -Action {
        $createdAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $safeTitle = Protect-AIWorkspaceMarkdownText -Value $InputTitle -Mode Inline
        $safeRequirement = Protect-AIWorkspaceMarkdownText -Value $InputRequirement -Mode Block
        $moduleName = Normalize-AIWorkspaceName -Value $InputTitle -AsciiOnly:$useAsciiNames
        $moduleName = Get-UniqueModuleName -BaseRoot $BaseRoot -Candidate $moduleName

        $moduleDir = Join-Path $BaseRoot (Join-Path "specs" $moduleName)
        New-Item -ItemType Directory -Path $moduleDir -Force | Out-Null

        $specPath = Join-Path $moduleDir "spec.md"
        $designPath = Join-Path $moduleDir "design.md"
        $tasksPath = Join-Path $moduleDir "tasks.md"

        $spec = @"
# Spec - $moduleName

## Title
$safeTitle

## Background
- $safeRequirement

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
- 优先复用本仓库工作区捆（``workspace`` / 兼容 ``codestatrFirst``）约定。

## Data / API
- Inputs:
  - 用户需求：$safeRequirement
- Outputs:
  - 可验证的功能行为 + 更新后的 specs/tasks
- Constraints:
  - 不破坏工作区捆结构；落盘 UTF-8 无 BOM

## Flow
1. 确认边界与验收标准
2. 实现最小可用方案并更新 tasks 状态
3. 按验收标准自测
"@

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
        $bundleLeaf = Split-Path -Leaf $BaseRoot
        $fields = Get-AIWorkspaceCacheSchema `
            -ModuleName $moduleName `
            -Title $safeTitle `
            -Requirement $safeRequirement `
            -Priority $priorityValue `
            -Status "initialized" `
            -OpenTodoCount $progress.Todo `
            -DoneCount $progress.Done `
            -CreatedAt $createdAt `
            -BundleDirName $bundleLeaf
        $cacheFile = Write-ModuleCacheJson -BundleRoot $BaseRoot -ModuleName $moduleName -Fields $fields

        Write-Host "Module ready: $moduleName"
        Write-Host "Specs:        $moduleDir"
        Write-Host "Cache:        $cacheFile"
    }
}

function Get-AIWorkspaceBatchItem {
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
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        # Comments: any line starting with # (including formerly ambiguous #title|req).
        # Data lines: title|requirement|priority(optional) — see requirements.batch.example.txt
        if ($line.StartsWith("#")) {
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
        Write-AIWorkspaceWarn "-Title/-Requirement ignored when -BatchFile is set."
    }
    if (-not [System.IO.Path]::IsPathRooted($BatchFile)) {
        $rel = ($BatchFile.Trim() -replace '^[/\\]+', '') -replace '^\.[/\\]+', ''
        $BatchFile = Join-Path $repoRoot $rel
    }

    $batchItems = @(Get-AIWorkspaceBatchItem -Path $BatchFile)
    if ($batchItems.Count -eq 0) {
        throw "Batch file has no valid items."
    }

    $batchHash = (Get-FileHash -LiteralPath $BatchFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $startIndex = 0
    $completed = @()
    if ($ResumeBatch) {
        $st = Read-AIWorkspaceBatchState -BundleRoot $WorkspaceBundle
        if ($st -and $st.batch_hash -eq $batchHash) {
            $startIndex = [int]$st.next_index
            $completed = @($st.completed)
            Write-AIWorkspaceInfo "Resuming batch at index $startIndex / $($batchItems.Count)"
        }
        else {
            Write-AIWorkspaceWarn "No matching batch state for -ResumeBatch; starting from beginning."
        }
    }

    Write-Host "Processing batch items: $($batchItems.Count) (from index $startIndex)"
    $created = @()
    for ($i = $startIndex; $i -lt $batchItems.Count; $i++) {
        $item = $batchItems[$i]
        try {
            New-RequirementModule -InputTitle $item.Title -InputRequirement $item.Requirement -InputPriority $item.Priority -BaseRoot $WorkspaceBundle -AsciiNames:$AsciiNames
            $completed += $item.Title
            $created += $item.Title
            Write-AIWorkspaceBatchState -BundleRoot $WorkspaceBundle -State ([ordered]@{
                    schema_version = 1
                    batch_file     = $BatchFile
                    batch_hash     = $batchHash
                    next_index     = ($i + 1)
                    completed      = $completed
                    updated_at     = (Get-Date).ToString("o")
                })
        }
        catch {
            Write-AIWorkspaceBatchState -BundleRoot $WorkspaceBundle -State ([ordered]@{
                    schema_version = 1
                    batch_file     = $BatchFile
                    batch_hash     = $batchHash
                    next_index     = $i
                    completed      = $completed
                    last_error     = $_.Exception.Message
                    updated_at     = (Get-Date).ToString("o")
                })
            Write-AIWorkspaceWarn "Batch stopped at index $i ($($item.Title)): $($_.Exception.Message)"
            Write-AIWorkspaceWarn "Re-run with -ResumeBatch -BatchFile `"$BatchFile`" to continue."
            if ($Json) {
                Write-AIWorkspaceJson ([ordered]@{
                        ok         = $false
                        next_index = $i
                        completed  = $completed
                        error      = $_.Exception.Message
                    })
            }
            exit (Get-AIWorkspaceExitCode -Kind Fail)
        }
    }
    Write-AIWorkspaceBatchState -BundleRoot $WorkspaceBundle -State ([ordered]@{
            schema_version = 1
            batch_file     = $BatchFile
            batch_hash     = $batchHash
            next_index     = $batchItems.Count
            completed      = $completed
            done           = $true
            updated_at     = (Get-Date).ToString("o")
        })
    Write-Host "Batch mode completed."
    if ($Json) {
        Write-AIWorkspaceJson ([ordered]@{ ok = $true; created = $created; completed = $completed })
    }
    exit (Get-AIWorkspaceExitCode -Kind Ok)
}

if ([string]::IsNullOrWhiteSpace($Title)) {
    if (Test-AIWorkspaceNonInteractive) {
        throw "Title is required in non-interactive mode (pass -Title or -BatchFile)."
    }
    $Title = Read-Host "Input requirement title"
}
if ([string]::IsNullOrWhiteSpace($Requirement)) {
    if (Test-AIWorkspaceNonInteractive) {
        throw "Requirement is required in non-interactive mode (pass -Requirement or -BatchFile)."
    }
    $Requirement = Read-Host "Input requirement detail"
}
if ([string]::IsNullOrWhiteSpace($Title) -or [string]::IsNullOrWhiteSpace($Requirement)) {
    throw "Title and Requirement are required."
}

New-RequirementModule -InputTitle $Title -InputRequirement $Requirement -InputPriority $Priority -BaseRoot $WorkspaceBundle -AsciiNames:$AsciiNames
Write-Host "Auto mode completed."
exit (Get-AIWorkspaceExitCode -Kind Ok)
