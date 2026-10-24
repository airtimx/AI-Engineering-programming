<#
.SYNOPSIS
Scan workspace cache + tasks.md; optional -SyncCache (never overwrite corrupt cache).
#>
param(
    [string]$Root = ".",
    [string]$Module = "",
    [switch]$SyncCache,
    [switch]$ExactModule,
    [switch]$AllowAmbiguousPrefix,
    [switch]$Json,
    [switch]$SuggestCommit,
    [switch]$DashboardOnly
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
Assert-AIWorkspaceToolkitReady -ToolkitDir $PSScriptRoot

$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot
$bundle = Get-AIWorkspaceBundlePath -RepositoryRoot $repoRoot
$bundleName = Resolve-AIWorkspaceBundleDirName -RepositoryRoot $repoRoot

if (-not (Test-Path -LiteralPath $bundle)) {
    throw "Workspace bundle not found: $bundle`nRun: ./skills/aiws.ps1 init"
}

$cacheDir = Join-Path $bundle "cache"
$specsDir = Join-Path $bundle "specs"
if (-not $Json -and -not $DashboardOnly) {
    Write-Host "=== AI Workspace Resume ==="
    Write-Host "Toolkit: $(Get-AIWorkspaceToolkitVersion)"
    Write-Host "Root:    $repoRoot"
    Write-Host "Bundle:  $bundle"
    Write-Host ""
}

$modules = @()
if (Test-Path -LiteralPath $specsDir) {
    $modules = @(Get-ChildItem -LiteralPath $specsDir -Directory | Select-Object -ExpandProperty Name)
}

if (-not [string]::IsNullOrWhiteSpace($Module)) {
    $want = Normalize-AIWorkspaceName -Value $Module
    if ($ExactModule) {
        $modules = @($modules | Where-Object { $_ -eq $want })
    }
    else {
        $exact = @($modules | Where-Object { $_ -eq $want })
        if ($exact.Count -gt 0) {
            $modules = $exact
        }
        else {
            $prefixed = @($modules | Where-Object { $_ -like "$want*" })
            if ($prefixed.Count -gt 1) {
                if (-not $AllowAmbiguousPrefix) {
                    $msg = "Ambiguous module prefix '$want' matches: $($prefixed -join ', ')`nUse -ExactModule or a fuller name. (-AllowAmbiguousPrefix picks the first match only.)"
                    if ($Json) {
                        Write-AIWorkspaceJson ([ordered]@{ ok = $false; error = $msg; matches = $prefixed })
                        exit (Get-AIWorkspaceExitCode -Kind Usage)
                    }
                    throw $msg
                }
                Write-AIWorkspaceWarn "Ambiguous prefix '$want'; using first match '$($prefixed[0])' (also matched: $($prefixed -join ', '))"
                $modules = @($prefixed[0])
            }
            else {
                $modules = $prefixed
            }
        }
    }
    if ($modules.Count -eq 0) {
        throw "Module not found under specs/: $Module"
    }
}

if ($modules.Count -eq 0) {
    if ($Json) {
        Write-AIWorkspaceJson ([ordered]@{ ok = $true; modules = @(); summary = [ordered]@{} })
    }
    else {
        Write-Host "No modules under specs/. Create one: ./skills/aiws.ps1 new -Title `"...`" -Requirement `"...`""
    }
    exit (Get-AIWorkspaceExitCode -Kind Ok)
}

$report = @()
foreach ($name in ($modules | Sort-Object)) {
    $tasksPath = Join-Path (Join-Path $specsDir $name) "tasks.md"
    $cachePath = Join-Path $cacheDir "$name.json"
    $progress = Get-TasksProgressSummary -TasksPath $tasksPath

    $status = "unknown"
    $title = $name
    $priority = ""
    $requirement = ""
    $createdAt = ""
    $owner = ""
    $cacheOk = $true

    if (Test-Path -LiteralPath $cachePath) {
        $read = Read-ModuleCacheJson -CachePath $cachePath
        if ($read.Ok) {
            $obj = $read.Object
            $p = $obj.PSObject.Properties["status"]; if ($null -ne $p -and $null -ne $p.Value) { $status = [string]$p.Value }
            $p = $obj.PSObject.Properties["title"]; if ($null -ne $p -and $null -ne $p.Value) { $title = [string]$p.Value }
            $p = $obj.PSObject.Properties["priority"]; if ($null -ne $p -and $null -ne $p.Value) { $priority = [string]$p.Value }
            $p = $obj.PSObject.Properties["requirement"]; if ($null -ne $p -and $null -ne $p.Value) { $requirement = [string]$p.Value }
            $p = $obj.PSObject.Properties["created_at"]; if ($null -ne $p -and $null -ne $p.Value) { $createdAt = [string]$p.Value }
            $p = $obj.PSObject.Properties["owner"]; if ($null -ne $p -and $null -ne $p.Value) { $owner = [string]$p.Value }
        }
        else {
            $cacheOk = $false
            Write-AIWorkspaceWarn "skip SyncCache for $name (corrupt cache preserved; see .bak)"
        }
    }

    if ($SyncCache -and $cacheOk) {
        $newStatus = Get-DerivedModuleStatus -Todo $progress.Todo -Done $progress.Done
        $writePriority = "P2"
        if ($priority -in @("P0", "P1", "P2", "P3")) {
            $writePriority = $priority
        }
        elseif (-not [string]::IsNullOrWhiteSpace($priority)) {
            Write-AIWorkspaceWarn "修正缓存优先级 ${priority}→P2"
            $writePriority = "P2"
        }
        $statusEnum = Get-AIWorkspaceStatusEnum
        if (-not [string]::IsNullOrWhiteSpace($status) -and ($statusEnum -notcontains $status)) {
            Write-AIWorkspaceWarn "修正缓存 status ${status}→$newStatus"
        }
        $fields = New-AIWorkspaceCacheSchema `
            -ModuleName $name `
            -Title $title `
            -Requirement $requirement `
            -Priority $writePriority `
            -Status $newStatus `
            -OpenTodoCount $progress.Todo `
            -DoneCount $progress.Done `
            -CreatedAt $(if ($createdAt) { $createdAt } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }) `
            -Owner $owner `
            -BundleDirName $bundleName
        Write-ModuleCacheJson -BundleRoot $bundle -ModuleName $name -Fields $fields | Out-Null
        $priority = $writePriority
        $status = $newStatus
    }
    elseif ($SyncCache -and -not $cacheOk) {
        Write-AIWorkspaceInfo "SyncCache skipped for $name to avoid data loss"
    }

    $me = Get-AIWorkspaceDefaultOwner
    $ownerConflict = Test-AIWorkspaceOwnerConflict -ModuleOwner $owner -Me $me
    if ($ownerConflict -and -not $Json) {
        Write-AIWorkspaceWarn "模块 $name 由 '$owner' 认领（当前 $me）。改任务前先: ./skills/aiws.ps1 claim -Module $name -Force 或与对方协调。"
    }

    $relTasks = "$bundleName/specs/$name/tasks.md"
    $nextTip = $null
    $agentPrompt = $null
    if ($progress.OpenItems.Count -gt 0) {
        $first = [string]$progress.OpenItems[0]
        $nextTip = "打开 $relTasks，勾完第 1 条「$first」后，再跑 ./skills/aiws.ps1 resume -SyncCache"
        $agentPrompt = "请在项目根实现模块「$title」的下一任务：$first。约束见 $bundleName/specs/$name/spec.md 与 design.md；完成后勾选 $relTasks 对应项。"
    }
    elseif ($status -eq "done" -or ($progress.Todo -eq 0 -and $progress.Done -gt 0)) {
        $nextTip = "模块 $name 无未完成 TODO；可开新需求或标记收尾。"
    }
    else {
        $nextTip = "模块 $name 暂无 open TODO；检查 $relTasks。"
    }

    $entry = [ordered]@{
        module         = $name
        title          = $title
        status         = $status
        priority       = $(if ($priority) { $priority } else { $null })
        owner          = $(if ($owner) { $owner } else { $null })
        owner_conflict = $ownerConflict
        todo           = $progress.Todo
        done           = $progress.Done
        open_tasks     = @($progress.OpenItems | Select-Object -First 5)
        next_tip       = $nextTip
        agent_prompt   = $agentPrompt
        files          = @(
            (Join-Path (Join-Path $specsDir $name) "spec.md")
            (Join-Path (Join-Path $specsDir $name) "design.md")
            $tasksPath
        )
    }
    $report += [pscustomobject]$entry

    if (-not $Json -and -not $DashboardOnly) {
        Write-Host "---- Module: $name ----"
        Write-Host "Title:    $title"
        $ownerPart = if ($owner) { "  Owner: $owner" } else { "" }
        Write-Host "Status:   $status  Priority: $(if ($priority) { $priority } else { '-' })$ownerPart"
        Write-Host "Progress: TODO=$($progress.Todo)  DONE=$($progress.Done)"
        Write-Host "Files:"
        Write-Host "  - $(Join-Path (Join-Path $specsDir $name) 'spec.md')"
        Write-Host "  - $(Join-Path (Join-Path $specsDir $name) 'design.md')"
        Write-Host "  - $tasksPath"
        if ($progress.OpenItems.Count -gt 0) {
            Write-Host "Next open tasks:"
            $i = 0
            foreach ($item in $progress.OpenItems) {
                $i++
                if ($i -gt 5) {
                    Write-Host "  ... +$($progress.OpenItems.Count - 5) more"
                    break
                }
                Write-Host "  $i. $item"
            }
        }
        Write-Host "下一步: $nextTip"
        if ($agentPrompt) {
            Write-Host "建议 Agent 提示词:"
            Write-Host "  $agentPrompt"
        }
        Write-Host ""
    }
}

# Dashboard summary
$counts = [ordered]@{
    initialized = @($report | Where-Object { $_.status -eq "initialized" }).Count
    in_progress = @($report | Where-Object { $_.status -eq "in_progress" }).Count
    done        = @($report | Where-Object { $_.status -eq "done" }).Count
    unknown     = @($report | Where-Object { $_.status -notin @("initialized", "in_progress", "done") }).Count
    blocked     = @($report | Where-Object { $_.todo -gt 0 -and $_.done -eq 0 -and $_.status -eq "in_progress" }).Count
}
# "阻塞" heuristic: in_progress with open todos but zero done (stalled start) — also count unknown with todos
$stalled = @($report | Where-Object { $_.todo -gt 0 -and $_.status -eq "unknown" }).Count
$counts["stalled"] = $stalled

if ($Json) {
    $payload = [ordered]@{
        ok      = $true
        toolkit = (Get-AIWorkspaceToolkitVersion)
        root    = $repoRoot
        bundle  = $bundle
        summary = $counts
        modules = $report
    }
    if ($SuggestCommit -or ($env:AIWORKSPACE_SUGGEST_COMMIT -eq "1")) {
        $focus = @($report | Where-Object { $_.todo -gt 0 } | Select-Object -First 1)
        if ($focus.Count -eq 0) { $focus = @($report | Select-Object -First 1) }
        if ($focus.Count -gt 0) {
            $m = $focus[0]
            $body = if ($m.open_tasks -and $m.open_tasks.Count -gt 0) { "Next: $($m.open_tasks[0])" } else { "Sync workspace cache/specs." }
            $payload["suggest_commit"] = "chore($($m.module)): $($m.done) done / $($m.todo) open — $body"
            $payload["suggest_pr_title"] = "[$($m.module)] $($m.title)"
            $payload["suggest_pr_body"] = @"
## Summary
- Module ``$($m.module)`` ($($m.status)): $($m.title)
- Progress: DONE=$($m.done) TODO=$($m.todo)
- Owner: $(if ($m.owner) { $m.owner } else { '(unclaimed)' })

## Test plan
- [ ] ``./skills/aiws.ps1 resume -SyncCache``
- [ ] Review ``$bundleName/specs/$($m.module)/tasks.md``
"@
        }
    }
    Write-AIWorkspaceJson $payload
}
else {
    Write-Host "=== 模块仪表盘 ==="
    Write-Host ("initialized={0}  in_progress={1}  done={2}  unknown={3}  stalled={4}" -f `
            $counts.initialized, $counts.in_progress, $counts.done, $counts.unknown, $counts.stalled)
    Write-Host ("{0,-24} {1,-12} {2,5} {3,5} {4}" -f "MODULE", "STATUS", "TODO", "DONE", "OWNER")
    foreach ($r in $report) {
        $ow = if ($r.owner) { $r.owner } else { "-" }
        Write-Host ("{0,-24} {1,-12} {2,5} {3,5} {4}" -f $r.module, $r.status, $r.todo, $r.done, $ow)
    }
    Write-Host ""

    $firstOpen = @($report | Where-Object { $_.todo -gt 0 } | Select-Object -First 1)
    if ($firstOpen.Count -gt 0 -and -not $DashboardOnly) {
        Write-Host "优先下一步: $($firstOpen[0].next_tip)"
        if ($firstOpen[0].agent_prompt) {
            Write-Host "优先 Agent 提示词: $($firstOpen[0].agent_prompt)"
        }
    }

    if ($SuggestCommit -or ($env:AIWORKSPACE_SUGGEST_COMMIT -eq "1")) {
        $focus = @($report | Where-Object { $_.todo -gt 0 } | Select-Object -First 1)
        if ($focus.Count -eq 0) { $focus = @($report | Select-Object -First 1) }
        if ($focus.Count -gt 0) {
            $m = $focus[0]
            $body = if ($m.open_tasks -and $m.open_tasks.Count -gt 0) { "Next: $($m.open_tasks[0])" } else { "Sync workspace cache/specs." }
            Write-Host ""
            Write-Host "建议 commit:"
            Write-Host "  chore($($m.module)): $($m.done) done / $($m.todo) open — $body"
            Write-Host "建议 PR 标题: [$($m.module)] $($m.title)"
            Write-Host "建议 PR 正文:"
            Write-Host "  ## Summary"
            Write-Host "  - Module $($m.module) ($($m.status)): $($m.title)"
            Write-Host "  - Progress: DONE=$($m.done) TODO=$($m.todo)"
            Write-Host "  （不会自动 git commit / gh pr create — 请自行粘贴）"
        }
    }

    if (-not $DashboardOnly) {
        Write-Host ""
        Write-Host "Tip: -SyncCache 刷新 cache；-SuggestCommit 输出提交建议；./skills/aiws.ps1 status 只看仪表盘。"
    }
}
exit (Get-AIWorkspaceExitCode -Kind Ok)
