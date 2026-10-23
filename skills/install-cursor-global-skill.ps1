<#
.SYNOPSIS
Install/update aiworkspace-manager into Cursor global skills + write manifest.json (SHA256).
Works on Windows PowerShell 5.1+ and PowerShell 7+.
#>
param(
    [string]$SourceRepo = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")

# Guard: do not resolve SourceRepo from toolkit parent
$here = $PSScriptRoot
$leaf = Split-Path -Leaf $here
if ($leaf -ieq "toolkit") {
    throw @"
Refusing to run installer from global toolkit directory:
  $here

Run from the template repository instead:
  pwsh -File `"<repo>/skills/install-cursor-global-skill.ps1`"
  # or: powershell -File `"<repo>/skills/install-cursor-global-skill.ps1`"
"@
}

if ([string]::IsNullOrWhiteSpace($SourceRepo)) {
    $SourceRepo = (Get-Item -LiteralPath (Split-Path -Parent $here)).FullName
}
else {
    $SourceRepo = (Get-Item -LiteralPath $SourceRepo).FullName
}

$srcCursorSkill = Join-Path $SourceRepo (Join-Path ".cursor" (Join-Path "skills" "aiworkspace-manager"))
$srcSkills = Join-Path $SourceRepo "skills"
$globalMd = Join-Path $srcCursorSkill "SKILL.global.md"
if (-not (Test-Path -LiteralPath $globalMd)) {
    throw "Missing SKILL.global.md under $srcCursorSkill`nIs SourceRepo the template repo root?"
}

$globalSkill = Get-AIWorkspaceGlobalSkillPath
$toolkit = Join-Path $globalSkill "toolkit"
New-Item -ItemType Directory -Path $toolkit -Force | Out-Null

Copy-Item -Path $globalMd -Destination (Join-Path $globalSkill "SKILL.md") -Force
Copy-Item -Path (Join-Path $srcCursorSkill "reference.md") -Destination (Join-Path $globalSkill "reference.md") -Force

$copyNames = @(
    "workspace-config.ps1", "init-workspace.ps1", "auto-requirement.ps1",
    "new-module-spec.ps1", "new-bugfix.ps1", "resume-workspace.ps1",
    "validate-workspace.ps1", "install-cursor-global-skill.ps1",
    "uninstall-cursor-global-skill.ps1", "run-tests.ps1", "analyze-workspace.ps1",
    "VERSION", "requirements.batch.txt"
)
foreach ($n in $copyNames) {
    $src = Join-Path $srcSkills $n
    if (Test-Path -LiteralPath $src) {
        Copy-Item -Path $src -Destination (Join-Path $toolkit $n) -Force
    }
}

# Build manifest
$ver = (Get-Content -LiteralPath (Join-Path $toolkit "VERSION") -Raw).Trim()
$files = @()
Get-ChildItem -LiteralPath $toolkit -File | ForEach-Object {
    if ($_.Name -eq "manifest.json") { return }
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $files += [ordered]@{ name = $_.Name; sha256 = $hash; bytes = $_.Length }
}
$manifest = [ordered]@{
    version      = $ver
    generated_at = (Get-Date).ToString("o")
    source_repo  = $SourceRepo
    runtime_note = "Windows PowerShell 5.1+ or PowerShell 7+ (Win/macOS/Linux)"
    files        = $files
}
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText(
    (Join-Path $toolkit "manifest.json"),
    ($manifest | ConvertTo-Json -Depth 6),
    $utf8
)

# Strict self-check after install
Test-AIWorkspaceManifest -ToolkitDir $toolkit -Strict | Out-Null

Write-Host "Installed global Cursor skill v$ver"
Write-Host "  $globalSkill"
Write-Host "  Toolkit: $toolkit"
Write-Host "  Manifest: $(Join-Path $toolkit 'manifest.json')"
Write-Host ""
Write-Host "Restart Cursor / new Agent chat, then @aiworkspace-manager"
Write-Host "Uninstall: pwsh -File `"$(Join-Path $srcSkills 'uninstall-cursor-global-skill.ps1')`""
