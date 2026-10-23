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
    [switch]$Json
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
Assert-AIWorkspaceToolkitReady -ToolkitDir $PSScriptRoot

$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot
$bundle = Get-AIWorkspaceBundlePath -RepositoryRoot $repoRoot

if (-not (Test-Path -LiteralPath $bundle)) {
    throw "Workspace bundle not found: $bundle`nRun init-workspace.ps1 first."
}

$cacheDir = Join-Path $bundle "cache"
$specsDir = Join-Path $bundle "specs"
if (-not $Json) {
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
        Write-AIWorkspaceJson ([ordered]@{ ok = $true; modules = @() })
    }
    else {
        Write-Host "No modules under specs/. Create one with auto-requirement.ps1 or new-module-spec.ps1."
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
    $cacheOk = $true

    if (Test-Path -LiteralPath $cachePath) {
        $read = Read-ModuleCacheJson -CachePath $cachePath
        if ($read.Ok) {
            $obj = $read.Object
            # StrictMode-safe: missing NoteProperties must not throw
            $p = $obj.PSObject.Properties["status"]; if ($null -ne $p -and $null -ne $p.Value) { $status = [string]$p.Value }
            $p = $obj.PSObject.Properties["title"]; if ($null -ne $p -and $null -ne $p.Value) { $title = [string]$p.Value }
            $p = $obj.PSObject.Properties["priority"]; if ($null -ne $p -and $null -ne $p.Value) { $priority = [string]$p.Value }
            $p = $obj.PSObject.Properties["requirement"]; if ($null -ne $p -and $null -ne $p.Value) { $requirement = [string]$p.Value }
            $p = $obj.PSObject.Properties["created_at"]; if ($null -ne $p -and $null -ne $p.Value) { $createdAt = [string]$p.Value }
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
            -CreatedAt $(if ($createdAt) { $createdAt } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") })
        Write-ModuleCacheJson -BundleRoot $bundle -ModuleName $name -Fields $fields | Out-Null
        $priority = $writePriority
        $status = $newStatus
    }
    elseif ($SyncCache -and -not $cacheOk) {
        Write-AIWorkspaceInfo "SyncCache skipped for $name to avoid data loss"
    }

    $entry = [ordered]@{
        module     = $name
        title      = $title
        status     = $status
        priority   = $(if ($priority) { $priority } else { $null })
        todo       = $progress.Todo
        done       = $progress.Done
        open_tasks = @($progress.OpenItems | Select-Object -First 5)
        files      = @(
            (Join-Path (Join-Path $specsDir $name) "spec.md")
            (Join-Path (Join-Path $specsDir $name) "design.md")
            $tasksPath
        )
    }
    $report += [pscustomobject]$entry

    if (-not $Json) {
        Write-Host "---- Module: $name ----"
        Write-Host "Title:    $title"
        Write-Host "Status:   $status  Priority: $(if ($priority) { $priority } else { '-' })"
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
        else {
            Write-Host "Next: no open TODO items (mark complete or add new tasks)."
        }
        Write-Host ""
    }
}

if ($Json) {
    Write-AIWorkspaceJson ([ordered]@{
            ok      = $true
            toolkit = (Get-AIWorkspaceToolkitVersion)
            root    = $repoRoot
            bundle  = $bundle
            modules = $report
        })
}
else {
    Write-Host "Tip: -SyncCache refreshes cache from tasks.md; corrupt JSON is never overwritten. Use -Json for machine-readable output."
}
exit (Get-AIWorkspaceExitCode -Kind Ok)
