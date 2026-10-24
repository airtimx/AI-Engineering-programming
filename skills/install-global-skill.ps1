<#
.SYNOPSIS
Install/update aiworkspace-manager into Cursor and/or Trae global skills + manifest.json (SHA256).
#>
param(
    [ValidateSet("Cursor", "Trae", "All")]
    [string]$IDE = "All",

    [string]$SourceRepo = "",

    # Override destination skill root (tests / CI). Ignored when -IDE All.
    [string]$SkillRoot = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "workspace-config.ps1")

$here = $PSScriptRoot
$leaf = Split-Path -Leaf $here
if ($leaf -ieq "toolkit") {
    throw @"
Refusing to run installer from global toolkit directory:
  $here

Run from the template repository instead:
  pwsh -File `"<repo>/skills/install-global-skill.ps1`" -IDE All
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

function Install-AIWorkspaceIdeSkill {
    param(
        [ValidateSet("Cursor", "Trae")][string]$TargetIde,
        [string]$DestSkillRoot
    )

    if ([string]::IsNullOrWhiteSpace($DestSkillRoot)) {
        $DestSkillRoot = Get-AIWorkspaceGlobalSkillPath -IDE $TargetIde
    }

    $toolkit = Join-Path $DestSkillRoot "toolkit"
    New-Item -ItemType Directory -Path $toolkit -Force | Out-Null

    if ($TargetIde -eq "Trae") {
        $skillBody = [System.IO.File]::ReadAllText($globalMd)
        $skillBody = $skillBody.Replace(".cursor\skills\", ".trae-cn\skills\").Replace(".cursor/skills/", ".trae-cn/skills/")
        $skillBody = $skillBody.Replace("Cursor project", "Trae project")
        $skillBody = $skillBody.Replace(
            ".\skills\install-global-skill.ps1",
            ".\skills\install-global-skill.ps1 -IDE Trae"
        )
        $skillBody = $skillBody.Replace(
            ".\skills\install-cursor-global-skill.ps1",
            ".\skills\install-global-skill.ps1 -IDE Trae"
        )
        Write-Utf8BomFile -Path (Join-Path $DestSkillRoot "SKILL.md") -Content $skillBody
    }
    else {
        $skillBody = [System.IO.File]::ReadAllText($globalMd)
        $skillBody = $skillBody.Replace(
            ".\skills\install-cursor-global-skill.ps1",
            ".\skills\install-global-skill.ps1"
        )
        Write-Utf8BomFile -Path (Join-Path $DestSkillRoot "SKILL.md") -Content $skillBody
    }
    Copy-Item -Path (Join-Path $srcCursorSkill "reference.md") -Destination (Join-Path $DestSkillRoot "reference.md") -Force

    $copyNames = @(
        "workspace-config.ps1", "init-workspace.ps1", "auto-requirement.ps1",
        "new-module-spec.ps1", "new-bugfix.ps1", "resume-workspace.ps1",
        "validate-workspace.ps1", "install-global-skill.ps1",
        "install-cursor-global-skill.ps1", "uninstall-global-skill.ps1",
        "uninstall-cursor-global-skill.ps1", "doctor-workspace.ps1", "aiws.ps1",
        "claim-module.ps1", "run-tests.ps1", "analyze-workspace.ps1",
        "VERSION", "requirements.batch.txt", "requirements.batch.example.txt"
    )
    foreach ($n in $copyNames) {
        $src = Join-Path $srcSkills $n
        if (Test-Path -LiteralPath $src) {
            Copy-AIWorkspaceScriptWithBom -SourcePath $src -DestinationPath (Join-Path $toolkit $n)
        }
    }

    $ver = (Get-Content -LiteralPath (Join-Path $toolkit "VERSION") -Raw).Trim()
    $files = @()
    Get-ChildItem -LiteralPath $toolkit -File | ForEach-Object {
        if ($_.Name -eq "manifest.json") { return }
        $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $files += [ordered]@{ name = $_.Name; sha256 = $hash; bytes = $_.Length }
    }
    $manifest = [ordered]@{
        version      = $ver
        ide          = $TargetIde
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
    Test-AIWorkspaceManifest -ToolkitDir $toolkit -Strict | Out-Null

    Write-Host "Installed global $TargetIde skill v$ver"
    Write-Host "  $DestSkillRoot"
    Write-Host "  Toolkit: $toolkit"
    Write-Host "  Manifest: $(Join-Path $toolkit 'manifest.json')"
}

$targets = @()
if ($IDE -eq "All") {
    if (-not [string]::IsNullOrWhiteSpace($SkillRoot)) {
        throw "-SkillRoot cannot be combined with -IDE All (install one IDE at a time for custom roots)."
    }
    $targets = @("Cursor", "Trae")
}
else {
    $targets = @(Resolve-AIWorkspaceIdeName -IDE $IDE)
}

foreach ($t in $targets) {
    $dest = $SkillRoot
    if ($IDE -eq "All") { $dest = "" }
    Install-AIWorkspaceIdeSkill -TargetIde $t -DestSkillRoot $dest
    Write-Host ""
}

Write-Host "Restart the IDE / new Agent chat, then @aiworkspace-manager"
Write-Host "Uninstall: pwsh -File `"$(Join-Path $srcSkills 'uninstall-global-skill.ps1')`" -IDE $IDE"
Write-Host "Doctor:    pwsh -File `"$(Join-Path $srcSkills 'aiws.ps1')`" doctor"
