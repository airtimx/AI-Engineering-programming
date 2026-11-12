<#
.SYNOPSIS
Remove global Cursor and/or Trae skill aiworkspace-manager (backup to .trash first).
#>
param(
    [ValidateSet("Cursor", "Trae", "All")]
    [string]$IDE = "All",

    [switch]$Force,

    [string]$SkillRoot = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")

function Uninstall-One {
    param(
        [ValidateSet("Cursor", "Trae")][string]$TargetIde,
        [string]$RootOverride,
        [switch]$Force
    )
    if ([string]::IsNullOrWhiteSpace($RootOverride)) {
        $globalSkill = Get-AIWorkspaceGlobalSkillPath -IDE $TargetIde
    }
    else {
        $globalSkill = $RootOverride
    }

    if (-not (Test-Path -LiteralPath $globalSkill)) {
        Write-Host "Not installed ($TargetIde): $globalSkill"
        return
    }

    if (-not $Force) {
        if (Test-AIWorkspaceNonInteractive) {
            throw "Non-interactive uninstall requires -Force."
        }
        $ans = Read-Host "Delete $TargetIde global skill at $globalSkill ? (y/N)"
        if ($ans -notmatch '^[yY]') {
            Write-Host "Cancelled ($TargetIde)."
            return
        }
    }

    $skillsParent = Split-Path -Parent $globalSkill
    $bakRoot = Join-Path $skillsParent ".trash"
    New-Item -ItemType Directory -Path $bakRoot -Force | Out-Null
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $bak = Join-Path $bakRoot "aiworkspace-manager-$stamp"
    Move-Item -LiteralPath $globalSkill -Destination $bak -Force
    Write-Host "Moved to backup: $bak"
    Write-Host "Global $TargetIde skill uninstalled."
}

if ($IDE -eq "All") {
    if (-not [string]::IsNullOrWhiteSpace($SkillRoot)) {
        throw "-SkillRoot cannot be combined with -IDE All."
    }
    Uninstall-One -TargetIde Cursor -RootOverride "" -Force:$Force
    Uninstall-One -TargetIde Trae -RootOverride "" -Force:$Force
}
else {
    $ide = Resolve-AIWorkspaceIdeName -IDE $IDE
    Uninstall-One -TargetIde $ide -RootOverride $SkillRoot -Force:$Force
}

exit (Get-AIWorkspaceExitCode -Kind Ok)
