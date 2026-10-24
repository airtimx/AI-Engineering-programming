<#
.SYNOPSIS
Claim / release / list module owners in workspace cache (lightweight multi-user).
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet("claim", "release", "who", "")]
    [string]$Action = "who",

    [string]$Root = ".",
    [string]$Module = "",
    [string]$Owner = "",
    [switch]$Force,
    [switch]$Json
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")
Assert-AIWorkspaceToolkitReady -ToolkitDir $PSScriptRoot

$repoRoot = Resolve-AIRepositoryRoot -Root $Root -ScriptHome $PSScriptRoot
$bundle = Get-AIWorkspaceBundlePath -RepositoryRoot $repoRoot
if (-not (Test-Path -LiteralPath $bundle)) {
    throw "Workspace bundle not found: $bundle`nRun: ./skills/aiws.ps1 init"
}

$specsDir = Join-Path $bundle "specs"
$modules = @()
if (Test-Path -LiteralPath $specsDir) {
    $modules = @(Get-ChildItem -LiteralPath $specsDir -Directory | Select-Object -ExpandProperty Name | Sort-Object)
}

if ($Action -eq "" -or $Action -eq "who") {
    $rows = @()
    foreach ($name in $modules) {
        if (-not [string]::IsNullOrWhiteSpace($Module) -and $name -ne (Normalize-AIWorkspaceName -Value $Module)) {
            # allow prefix-ish: exact folder name match after normalize of filter
            $want = Normalize-AIWorkspaceName -Value $Module
            if ($name -ne $want) { continue }
        }
        $ow = Get-AIWorkspaceModuleOwner -BundleRoot $bundle -ModuleName $name
        $rows += [pscustomobject]@{ module = $name; owner = $(if ($ow) { $ow } else { "-" }) }
    }
    if ($Json) {
        Write-AIWorkspaceJson ([ordered]@{
                ok      = $true
                me      = (Get-AIWorkspaceDefaultOwner)
                modules = $rows
            })
    }
    else {
        Write-Host "=== Module owners (me=$(Get-AIWorkspaceDefaultOwner)) ==="
        Write-Host ("{0,-28} {1}" -f "MODULE", "OWNER")
        foreach ($r in $rows) {
            Write-Host ("{0,-28} {1}" -f $r.module, $r.owner)
        }
        if ($rows.Count -eq 0) {
            Write-Host "(no modules)"
        }
    }
    exit (Get-AIWorkspaceExitCode -Kind Ok)
}

if ([string]::IsNullOrWhiteSpace($Module)) {
    throw "claim/release requires -Module <name>"
}
$modName = Normalize-AIWorkspaceName -Value $Module
if (-not (Test-Path -LiteralPath (Join-Path $specsDir $modName))) {
    # try exact folder if normalize differs
    if (Test-Path -LiteralPath (Join-Path $specsDir $Module)) {
        $modName = $Module
    }
    else {
        throw "Module not found: $Module"
    }
}

if ($Action -eq "claim") {
    $path = Set-AIWorkspaceModuleOwner -BundleRoot $bundle -ModuleName $modName -Owner $Owner -Force:$Force
    $ow = Get-AIWorkspaceModuleOwner -BundleRoot $bundle -ModuleName $modName
    if ($Json) {
        Write-AIWorkspaceJson ([ordered]@{ ok = $true; action = "claim"; module = $modName; owner = $ow; cache = $path })
    }
    else {
        Write-Host "Claimed module '$modName' -> owner=$ow"
        Write-Host "Cache: $path"
    }
    exit (Get-AIWorkspaceExitCode -Kind Ok)
}

if ($Action -eq "release") {
    $me = if ($Owner) { $Owner } else { Get-AIWorkspaceDefaultOwner }
    $cur = Get-AIWorkspaceModuleOwner -BundleRoot $bundle -ModuleName $modName
    if (-not [string]::IsNullOrWhiteSpace($cur) -and -not [string]::IsNullOrWhiteSpace($me) -and ($cur -ne $me) -and -not $Force) {
        throw "Cannot release: owned by '$cur' (you are '$me'). Use -Force."
    }
    $path = Set-AIWorkspaceModuleOwner -BundleRoot $bundle -ModuleName $modName -Clear
    if ($Json) {
        Write-AIWorkspaceJson ([ordered]@{ ok = $true; action = "release"; module = $modName; owner = $null; cache = $path })
    }
    else {
        Write-Host "Released module '$modName' (owner cleared)"
        Write-Host "Cache: $path"
    }
    exit (Get-AIWorkspaceExitCode -Kind Ok)
}

throw "Unknown action: $Action"
