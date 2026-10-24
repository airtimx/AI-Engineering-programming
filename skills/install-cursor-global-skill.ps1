<#
.SYNOPSIS
DEPRECATED — use install-global-skill.ps1 (-IDE Cursor|Trae|All).
#>
param(
    [ValidateSet("Cursor", "Trae", "All")]
    [string]$IDE = "Cursor",

    [string]$SourceRepo = "",

    [string]$SkillRoot = ""
)

Write-Warning "DEPRECATED: install-cursor-global-skill.ps1 → use install-global-skill.ps1 (same parameters)."
& (Join-Path $PSScriptRoot "install-global-skill.ps1") -IDE $IDE -SourceRepo $SourceRepo -SkillRoot $SkillRoot
