<#
.SYNOPSIS
Scan codestatrFirst cache + tasks.md; optional -SyncCache (never overwrite corrupt cache).
#>
param(
    [string]$Root = ".",
    [string]$Module = "",
    [switch]$SyncCache,
    [switch]$ExactModule,
    [switch]$AllowAmbiguousPrefix
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
Write-Host "=== AI Workspace Resume ==="
Write-Host "Toolkit: $(Get-AIWorkspaceToolkitVersion)"
Write-Host "Root:    $repoRoot"
Write-Host "Bundle:  $bundle"
Write-Host ""

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
        # Exact match preferred; prefix only if no exact hit
        $exact = @($modules | Where-Object { $_ -eq $want })
        if ($exact.Count -gt 0) {
            $modules = $exact
        }
        else {
            $modules = @($modules | Where-Object { $_ -like "$want*" })
            if ($modules.Count -gt 1 -and -not $AllowAmbiguousPrefix) {
                throw "Ambiguous module prefix '$want' matches: $($modules -join ', ')`nUse -ExactModule, a fuller name, or -AllowAmbiguousPrefix."
            }
            if ($modules.Count -gt 1) {
                Write-Host "WARN: multiple modules match prefix '$want': $($modules -join ', ')"
            }
        }
    }
    if ($modules.Count -eq 0) {
        throw "Module not found under specs/: $Module"
    }
}

if ($modules.Count -eq 0) {
    Write-Host "No modules under specs/. Create one with auto-requirement.ps1 or new-module-spec.ps1."
    exit 0
}

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
        $read = Read-ModuleCacheJson -CachePath $cachePath -NoOverwriteOnError
        if ($read.Ok) {
            $obj = $read.Object
            if ($obj.status) { $status = [string]$obj.status }
            if ($obj.title) { $title = [string]$obj.title }
            if ($obj.priority) { $priority = [string]$obj.priority }
            if ($obj.requirement) { $requirement = [string]$obj.requirement }
            if ($obj.created_at) { $createdAt = [string]$obj.created_at }
        }
        else {
            $cacheOk = $false
            Write-Host "WARN: skip SyncCache for $name (corrupt cache preserved; see .bak)"
        }
    }

    if ($SyncCache -and $cacheOk) {
        $newStatus = Get-DerivedModuleStatus -Todo $progress.Todo -Done $progress.Done
        $fields = New-AIWorkspaceCacheSchema `
            -ModuleName $name `
            -Title $title `
            -Requirement $requirement `
            -Priority $(if ($priority -in @("P0", "P1", "P2", "P3")) { $priority } else { "P2" }) `
            -Status $newStatus `
            -OpenTodoCount $progress.Todo `
            -DoneCount $progress.Done `
            -CreatedAt $(if ($createdAt) { $createdAt } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") })
        Write-ModuleCacheJson -BundleRoot $bundle -ModuleName $name -Fields $fields | Out-Null
        $status = $newStatus
    }
    elseif ($SyncCache -and -not $cacheOk) {
        Write-Host "INFO: SyncCache skipped for $name to avoid data loss"
    }

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

Write-Host "Tip: -SyncCache refreshes cache from tasks.md; corrupt JSON is never overwritten."
