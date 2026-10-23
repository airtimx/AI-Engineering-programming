<#
.SYNOPSIS
Remove global Cursor skill aiworkspace-manager (backup to .trash first).
#>
param(
    [switch]$Force,
    [string]$SkillRoot = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")

if ([string]::IsNullOrWhiteSpace($SkillRoot)) {
    $globalSkill = Get-AIWorkspaceGlobalSkillPath
}
else {
    $globalSkill = $SkillRoot
}

if (-not (Test-Path -LiteralPath $globalSkill)) {
    Write-Host "Not installed: $globalSkill"
    exit 0
}

if (-not $Force) {
    $ans = Read-Host "Delete global skill at $globalSkill ? (y/N)"
    if ($ans -notmatch '^[yY]') {
        Write-Host "Cancelled."
        exit 0
    }
}

$skillsParent = Split-Path -Parent $globalSkill
$bakRoot = Join-Path $skillsParent ".trash"
New-Item -ItemType Directory -Path $bakRoot -Force | Out-Null
$stamp = Get-Date -Format "yyyyMMddHHmmss"
$bak = Join-Path $bakRoot "aiworkspace-manager-$stamp"
Move-Item -LiteralPath $globalSkill -Destination $bak -Force
Write-Host "Moved to backup: $bak"
Write-Host "Global skill uninstalled."
