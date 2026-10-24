<#
.SYNOPSIS
DEPRECATED — use uninstall-global-skill.ps1 (-IDE Cursor|Trae|All).
#>
param(
    [ValidateSet("Cursor", "Trae", "All")]
    [string]$IDE = "Cursor",

    [switch]$Force,

    [string]$SkillRoot = ""
)

Write-Warning "DEPRECATED: uninstall-cursor-global-skill.ps1 → use uninstall-global-skill.ps1."
& (Join-Path $PSScriptRoot "uninstall-global-skill.ps1") -IDE $IDE -Force:$Force -SkillRoot $SkillRoot
exit $LASTEXITCODE
